// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/extension_manager.h"

#import <Foundation/Foundation.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>

#include "include/base/cef_callback.h"
#include "include/base/cef_logging.h"
#include "include/cef_parser.h"
#include "include/cef_task.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

#include "extensions/extension_scheme.h"
#include "extensions/github.h"
#include "extensions/package.h"
#include "popout/popout_scripts.h"
#include "ui/ui_scheme.h"

namespace {

constexpr char kDataFolder[] = "openp41ge Extensions";
constexpr char kInstalledFile[] = "installed.json";
// Where GitHub installs go (installed/<id>/<version>), and where they're
// unpacked first, before the user accepts (cleared at startup).
constexpr char kInstalledFolder[] = "installed";
constexpr char kStagingFolder[] = "staging";
constexpr size_t kMaxPackageBytes = 20 * 1024 * 1024;
constexpr char kConfigFile[] = "config.json";
constexpr char kFeaturesFile[] = "features.json";

// A file in the app bundle's extension-runtime/ folder.
std::string Resource(NSString* name) {
  NSString* path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:name];
  NSString* text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  LOG_IF(ERROR, !text) << "Missing from the app: " << path.UTF8String;
  return text ? std::string(text.UTF8String) : std::string();
}

// app/extensions/runtime.js.
const std::string& Runtime() {
  static const std::string runtime = Resource(@"extension-runtime/runtime.js");
  return runtime;
}

// app/extensions/page-runtime.js.
const std::string& PageRuntime() {
  static const std::string runtime = Resource(@"extension-runtime/page-runtime.js");
  return runtime;
}

// A function's source that returns app/extensions/settings.js's helpers,
// made with the code editor's config logic
// (third_party/openp41ge-uikit/config.js, a script that defines
// `openp41geConfig`).
const std::string& LoadSettings() {
  static const std::string load = "function () {\n" + Resource(@"extension-runtime/config.js") + "\nreturn (" +
                                  Resource(@"extension-runtime/settings.js") + ")(openp41geConfig);\n}";
  return load;
}

// app/extensions/messages.js (an expression: the runtimes call it).
const std::string& Messages() {
  static const std::string messages = Resource(@"extension-runtime/messages.js");
  return messages;
}

// How long a broadcast waits for replies at most (the runtimes give each
// handler 5 s).
constexpr int kBroadcastTimeoutMs = 6000;

// The name of the function an extension's world sends to the browser with
// (Runtime.addBinding): one per extension, so its name says which.
std::string BindingName(const std::string& id) {
  std::string name = "__openp41geSend_" + id;
  for (char& c : name) {
    if (c == '-') c = '_';
  }
  return name;
}

// The extension's features, as the user set them, for the runtimes.
CefRefPtr<CefListValue> FeatureList(const Extension& extension, CefRefPtr<CefDictionaryValue> features) {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const Extension::Feature& feature : extension.features) {
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetString("id", feature.id);
    item->SetString("name", feature.name);
    item->SetBool("enabled", features->GetType(feature.id) == VTYPE_BOOL ? features->GetBool(feature.id)
                                                                         : feature.enabled_by_default);
    list->SetDictionary(list->GetSize(), item);
  }
  return list;
}

// The JSON object in `path`; an empty one if there's no file. One that
// isn't a JSON object is logged and read as empty (and left as it is).
CefRefPtr<CefDictionaryValue> ReadObject(const std::string& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) return CefDictionaryValue::Create();
  const std::string text((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
  CefString error;
  CefRefPtr<CefValue> parsed = CefParseJSONAndReturnError(text, JSON_PARSER_RFC, error);
  if (!parsed || parsed->GetType() != VTYPE_DICTIONARY) {
    LOG(ERROR) << "Ignoring " << path << ": not a JSON object" << (error.empty() ? "" : " (" + error.ToString() + ")");
    return CefDictionaryValue::Create();
  }
  return parsed->GetDictionary()->Copy(false);
}

// Writes `text` to `path` whole (a partial file, then renamed), making its
// folder. File thread.
void WriteFile(const std::string& path, const std::string& text) {
  namespace fs = std::filesystem;
  std::error_code error;
  fs::create_directories(fs::path(path).parent_path(), error);
  const std::string partial = path + ".partial";
  {
    std::ofstream stream(partial, std::ios::binary | std::ios::trunc);
    stream << text;
    if (!stream) {
      LOG(ERROR) << "Couldn't write " << partial;
      return;
    }
  }
  fs::rename(partial, path, error);
  LOG_IF(ERROR, error) << "Couldn't write " << path << ": " << error.message();
}

// Deletes `path` and what's in it. File thread.
void DeleteFolder(const std::string& path) {
  std::error_code error;
  std::filesystem::remove_all(path, error);
  LOG_IF(ERROR, error) << "Couldn't delete " << path << ": " << error.message();
}

// A folder picker's answer, to a function.
class FolderChosen : public CefRunFileDialogCallback {
 public:
  explicit FolderChosen(std::function<void(const std::string&)> done) : done_(std::move(done)) {}
  void OnFileDialogDismissed(const std::vector<CefString>& paths) override {
    done_(paths.empty() ? std::string() : paths.front().ToString());
  }

 private:
  std::function<void(const std::string&)> done_;
  IMPLEMENT_REFCOUNTING(FolderChosen);
};

std::string Json(CefRefPtr<CefValue> value) {
  return CefWriteJSON(value, JSON_WRITER_DEFAULT).ToString();
}

std::string Json(CefRefPtr<CefDictionaryValue> dictionary) {
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(dictionary->Copy(false));
  return Json(value);
}

std::string JsonString(const std::string& text) {
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetString(text);
  return Json(value);
}

// A function whose body is `code`: how a file runs in the runtime.
std::string AsFunction(const std::string& code) {
  return "function () {\n" + code + "\n}";
}

// The extension's config for the runtimes ({ schema, values }), or null.
std::string ConfigJson(const Extension& extension, CefRefPtr<CefDictionaryValue> values) {
  if (extension.config_schema.empty()) return "null";
  return "{ \"schema\": " + extension.config_schema + ", \"values\": " + Json(values) + " }";
}

// The script that runs in each document's content-script world: the
// runtime, called with the extension (its content scripts, with their CSS;
// its config schema and the user's values), each content script's JS files
// as functions, packages/popout's core.js as a function, and one returning
// the settings helpers. `features`: the user's feature toggles
// (features.json); `values`: their settings (config.json).
std::string ContentScript(const Extension& extension,
                          CefRefPtr<CefDictionaryValue> features,
                          CefRefPtr<CefDictionaryValue> values) {
  CefRefPtr<CefListValue> content_scripts = CefListValue::Create();
  std::string scripts = "[";
  for (const Extension::ContentScript& script : extension.content_scripts) {
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    CefRefPtr<CefListValue> matches = CefListValue::Create();
    for (const std::string& pattern : script.matches) matches->SetString(matches->GetSize(), pattern);
    item->SetList("matches", matches);
    CefRefPtr<CefListValue> css = CefListValue::Create();
    for (const Extension::File& file : script.css) css->SetString(css->GetSize(), file.text);
    item->SetList("css", css);
    item->SetBool("runAtStart", script.run_at_start);
    item->SetString("feature", script.feature);
    content_scripts->SetDictionary(content_scripts->GetSize(), item);

    scripts += "[";
    for (const Extension::File& file : script.js) {
      scripts += "{ path: " + JsonString(file.path) + ", run: " + AsFunction(file.text) + " },\n";
    }
    scripts += "],\n";
  }
  scripts += "]";

  CefRefPtr<CefDictionaryValue> info = CefDictionaryValue::Create();
  info->SetString("id", extension.id);
  info->SetString("name", extension.name);
  info->SetString("version", extension.version);
  info->SetList("contentScripts", content_scripts);
  info->SetList("features", FeatureList(extension, features));
  info->SetString("binding", BindingName(extension.id));
  // The runtime reads `config` from the extension.
  std::string info_json = Json(info);
  info_json.pop_back();  // The closing brace.
  info_json += ",\"config\":" + ConfigJson(extension, values) + "}";

  return "(" + Runtime() + ")(\n" + info_json + ",\n" + scripts + ",\n" + AsFunction(popout_scripts::Library()) +
         ",\n" + LoadSettings() + ",\n" + Messages() + ");\n";
}

// The script that runs in each document's own world, for the extension's
// pages: the page runtime, called with the extension, its config, the
// settings helpers and messages.js.
std::string PageScript(const Extension& extension,
                       CefRefPtr<CefDictionaryValue> features,
                       CefRefPtr<CefDictionaryValue> values) {
  CefRefPtr<CefDictionaryValue> info = CefDictionaryValue::Create();
  info->SetString("id", extension.id);
  info->SetString("name", extension.name);
  info->SetString("version", extension.version);
  CefRefPtr<CefListValue> pages = CefListValue::Create();
  for (const Extension::Page& page : extension.pages) {
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetString("path", page.path);
    item->SetString("title", page.title);
    item->SetBool("settings", page.settings);
    pages->SetDictionary(pages->GetSize(), item);
  }
  info->SetList("pages", pages);
  info->SetList("features", FeatureList(extension, features));
  return "(" + PageRuntime() + ")(\n" + Json(info) + ",\n" + ConfigJson(extension, values) + ",\n" +
         LoadSettings() + ",\n" + Messages() + ");\n";
}

// Evaluates `expression` in the page's top frame, in the isolated world
// `world` (the same world each time: the one the extension's scripts run
// in); `callback` (optional) gets its value (by value, a returned promise
// awaited if `await`), or null.
void EvaluateInWorld(CefRefPtr<DevToolsClient> devtools,
                     CefRefPtr<CefBrowser> browser,
                     const std::string& world,
                     const std::string& expression,
                     bool await,
                     DevToolsClient::ValueCallback callback) {
  auto fail = [callback] {
    if (callback) callback(nullptr);
  };
  devtools->Call(browser, "Page.getFrameTree", nullptr, [=](CefRefPtr<CefDictionaryValue> tree) {
    CefRefPtr<CefDictionaryValue> frame_tree = tree ? tree->GetDictionary("frameTree") : nullptr;
    CefRefPtr<CefDictionaryValue> frame = frame_tree ? frame_tree->GetDictionary("frame") : nullptr;
    if (!frame) return fail();
    CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
    params->SetString("frameId", frame->GetString("id"));
    params->SetString("worldName", world);
    devtools->Call(browser, "Page.createIsolatedWorld", params, [=](CefRefPtr<CefDictionaryValue> created) {
      if (!created || !created->HasKey("executionContextId")) return fail();
      CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
      params->SetString("expression", expression);
      params->SetInt("contextId", created->GetInt("executionContextId"));
      params->SetBool("returnByValue", true);
      if (await) params->SetBool("awaitPromise", true);
      devtools->Call(browser, "Runtime.evaluate", params, [callback](CefRefPtr<CefDictionaryValue> result) {
        if (!callback) return;
        CefRefPtr<CefDictionaryValue> inner = result ? result->GetDictionary("result") : nullptr;
        callback(inner && inner->HasKey("value") ? inner->GetValue("value") : nullptr);
      });
    });
  });
}

}  // namespace

ExtensionManager::ExtensionManager(CefRefPtr<DevToolsClient> devtools,
                                   const std::string& profile_folder,
                                   OpenTab open_tab)
    : devtools_(devtools),
      data_folder_(profile_folder + "/" + kDataFolder),
      secrets_(profile_folder),
      open_tab_(std::move(open_tab)) {
  devtools_->OnEvent("Runtime.bindingCalled", [this](CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> params) {
    OnBindingCalled(browser, params);
  });
}

void ExtensionManager::Start(const std::vector<std::string>& folders) {
  // The installed ones: [{ "folder": …, "enabled": bool }].
  CefRefPtr<CefValue> parsed;
  {
    std::ifstream stream(data_folder_ + "/" + kInstalledFile, std::ios::binary);
    const std::string text((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
    if (!text.empty()) parsed = CefParseJSON(text, JSON_PARSER_RFC);
    LOG_IF(ERROR, !text.empty() && (!parsed || parsed->GetType() != VTYPE_LIST))
        << "Ignoring " << data_folder_ << "/" << kInstalledFile << ": not a JSON list";
  }
  CefRefPtr<CefListValue> installed = parsed && parsed->GetType() == VTYPE_LIST ? parsed->GetList() : nullptr;
  for (size_t i = 0; installed && i < installed->GetSize(); ++i) {
    CefRefPtr<CefDictionaryValue> item = installed->GetDictionary(i);
    if (!item || item->GetType("folder") != VTYPE_STRING) continue;
    Loaded& loaded = Add(item->GetString("folder"), /*installed=*/true,
                         item->GetType("enabled") != VTYPE_BOOL || item->GetBool("enabled"));
    if (CefRefPtr<CefDictionaryValue> from = item->GetDictionary("github")) {
      loaded.github_repo = from->GetString("repo");
      loaded.github_tag = from->GetString("tag");
      loaded.github_sha256 = from->GetString("sha256");
    }
  }
  // Downloads the user never accepted, from an earlier run.
  CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, data_folder_ + "/" + kStagingFolder));
  // And this run's.
  for (const std::string& folder : folders) {
    if (!FindSource(folder)) Add(folder, /*installed=*/false, /*enabled=*/true);
  }
}

bool ExtensionManager::HasExtensions() const {
  for (const Loaded& loaded : loaded_) {
    if (loaded.active()) return true;
  }
  return false;
}

ExtensionManager::Loaded& ExtensionManager::Add(const std::string& source, bool installed, bool enabled) {
  Loaded& loaded = loaded_.emplace_back();
  loaded.source = source;
  loaded.installed = installed;
  loaded.enabled = enabled;
  Load(loaded);
  if (loaded.active()) Activate(loaded);
  return loaded;
}

void ExtensionManager::Load(Loaded& loaded) {
  std::string error;
  std::optional<Extension> extension = extensions::Load(loaded.source, &error);
  if (extension) {
    for (const Loaded& other : loaded_) {
      if (&other != &loaded && other.error.empty() && other.extension.id == extension->id) {
        error = "another extension has the id \"" + extension->id + "\" (" + other.source + ")";
        extension.reset();
        break;
      }
    }
  }
  if (!extension) {
    LOG(ERROR) << "Extension not loaded: " << error;
    loaded.error = error;
    return;
  }
  LOG(INFO) << "Extension loaded: " << extension->name << " (" << extension->id << " " << extension->version
            << ") from " << extension->folder;
  loaded.error.clear();
  loaded.world = "openp41ge-extension:" + extension->id;
  loaded.binding = BindingName(extension->id);
  loaded.data = data_folder_ + "/" + extension->id;
  loaded.features = ReadObject(loaded.data + "/" + kFeaturesFile);
  for (const Extension::Feature& feature : extension->features) {
    if (loaded.features->HasKey(feature.id) && loaded.features->GetType(feature.id) != VTYPE_BOOL) {
      LOG(ERROR) << "Ignoring " << loaded.data << "/" << kFeaturesFile << "'s \"" << feature.id
                 << "\": not true or false";
    }
  }
  loaded.values = ReadObject(loaded.data + "/" + kConfigFile);
  loaded.extension = std::move(*extension);
  // Its secret settings: from the SecretStore; one in config.json (written
  // by hand, or before secrets were kept apart) moves there.
  loaded.secret_keys.clear();
  loaded.secrets = CefDictionaryValue::Create();
  CefRefPtr<CefValue> schema = loaded.extension.config_schema.empty()
                                   ? nullptr
                                   : CefParseJSON(loaded.extension.config_schema, JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> properties =
      schema && schema->GetType() == VTYPE_DICTIONARY ? schema->GetDictionary()->GetDictionary("properties") : nullptr;
  CefDictionaryValue::KeyList keys;
  if (properties) properties->GetKeys(keys);
  bool moved = false;
  for (const CefString& key : keys) {
    CefRefPtr<CefDictionaryValue> property = properties->GetDictionary(key);
    if (!property || property->GetType("secret") != VTYPE_BOOL || !property->GetBool("secret")) continue;
    loaded.secret_keys.push_back(key);
    if (loaded.values->HasKey(key)) {
      if (loaded.values->GetType(key) == VTYPE_STRING) secrets_.Set(loaded.extension.id, key, loaded.values->GetString(key));
      loaded.values->Remove(key);
      moved = true;
    }
    if (std::optional<std::string> secret = secrets_.Get(loaded.extension.id, key)) loaded.secrets->SetString(key, *secret);
  }
  if (moved) {
    CefPostTask(TID_FILE_USER_BLOCKING,
                base::BindOnce(&WriteFile, loaded.data + "/" + kConfigFile, Json(loaded.values)));
  }
  BuildScripts(loaded);
}

void ExtensionManager::Activate(Loaded& loaded) {
  extension_scheme::Serve(loaded.extension, NSBundle.mainBundle.resourcePath.UTF8String);
  for (auto& [page_id, page] : pages_) AttachTo(page_id, loaded, nullptr);
}

void ExtensionManager::Deactivate(Loaded& loaded) {
  extension_scheme::Unserve(loaded.extension.id);
  for (auto& [page_id, page] : pages_) DetachFrom(page, loaded);
}

void ExtensionManager::EnableDomains(Page& page) {
  if (page.domains) return;
  page.domains = true;
  // Scripts added for new documents run only while the page domain is on;
  // a binding for a named world reaches worlds made later only while the
  // runtime domain is.
  devtools_->Call(page.browser, "Page.enable", nullptr);
  devtools_->Call(page.browser, "Runtime.enable", nullptr);
}

void ExtensionManager::AttachTo(int page_id, const Loaded& loaded, std::function<void()> done) {
  auto page = pages_.find(page_id);
  if (page == pages_.end()) return;
  EnableDomains(page->second);
  // The function its world sends to the browser with, in its world only.
  // It reaches a new document's world just after the document's first
  // scripts run: the runtime looks it up when it sends.
  CefRefPtr<CefDictionaryValue> binding = CefDictionaryValue::Create();
  binding->SetString("name", loaded.binding);
  binding->SetString("executionContextName", loaded.world);
  devtools_->Call(page->second.browser, "Runtime.addBinding", binding);
  AddScripts(page_id, loaded, std::move(done));
}

void ExtensionManager::DetachFrom(Page& page, const Loaded& loaded) {
  auto scripts = page.scripts.find(loaded.extension.id);
  if (scripts == page.scripts.end()) return;
  for (const std::string& identifier : scripts->second) {
    CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
    params->SetString("identifier", identifier);
    devtools_->Call(page.browser, "Page.removeScriptToEvaluateOnNewDocument", params);
  }
  page.scripts.erase(scripts);
  CefRefPtr<CefDictionaryValue> binding = CefDictionaryValue::Create();
  binding->SetString("name", loaded.binding);
  devtools_->Call(page.browser, "Runtime.removeBinding", binding);
}

void ExtensionManager::SaveInstalled() {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const Loaded& loaded : loaded_) {
    if (!loaded.installed) continue;
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetString("folder", loaded.source);
    item->SetBool("enabled", loaded.enabled);
    if (!loaded.github_repo.empty()) {
      CefRefPtr<CefDictionaryValue> from = CefDictionaryValue::Create();
      from->SetString("repo", loaded.github_repo);
      from->SetString("tag", loaded.github_tag);
      from->SetString("sha256", loaded.github_sha256);
      item->SetDictionary("github", from);
    }
    list->SetDictionary(list->GetSize(), item);
  }
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetList(list);
  CefPostTask(TID_FILE_USER_BLOCKING,
              base::BindOnce(&WriteFile, data_folder_ + "/" + kInstalledFile,
                             CefWriteJSON(value, JSON_WRITER_PRETTY_PRINT).ToString()));
}

ExtensionManager::Loaded* ExtensionManager::Find(const std::string& id) {
  for (Loaded& loaded : loaded_) {
    if (loaded.active() && loaded.extension.id == id) return &loaded;
  }
  return nullptr;
}

ExtensionManager::Loaded* ExtensionManager::FindSource(const std::string& source) {
  for (Loaded& loaded : loaded_) {
    if (loaded.source == source) return &loaded;
  }
  return nullptr;
}

void ExtensionManager::BuildScripts(Loaded& loaded) {
  loaded.content_script = ContentScript(loaded.extension, loaded.features, ContentValues(loaded));
  loaded.page_script = PageScript(loaded.extension, loaded.features, PageValues(loaded));
}

void ExtensionManager::OnPageCreated(CefRefPtr<CefBrowser> browser, std::function<void()> ready) {
  CEF_REQUIRE_UI_THREAD();
  // Every page is known, so an extension added later reaches it too.
  pages_[browser->GetIdentifier()] = {browser, false, {}};
  size_t active = 0;
  for (const Loaded& loaded : loaded_) active += loaded.active();
  if (!active) {
    if (ready) ready();
    return;
  }
  // `ready` runs once every extension's scripts are added.
  auto waiting = std::make_shared<size_t>(active);
  for (const Loaded& loaded : loaded_) {
    if (!loaded.active()) continue;
    AttachTo(browser->GetIdentifier(), loaded, [waiting, ready] {
      if (--*waiting == 0 && ready) ready();
    });
  }
}

void ExtensionManager::OnPageClosed(CefRefPtr<CefBrowser> browser) {
  pages_.erase(browser->GetIdentifier());
}

void ExtensionManager::AddScripts(int page_id, const Loaded& loaded, std::function<void()> done) {
  auto page = pages_.find(page_id);
  if (page == pages_.end()) return;
  CefRefPtr<CefBrowser> browser = page->second.browser;
  const std::string id = loaded.extension.id;
  const std::string world = loaded.world;
  const std::string content_script = loaded.content_script;
  const std::string page_script = loaded.page_script;
  // What was registered before, removed once the new ones are in.
  auto previous = std::make_shared<std::vector<std::string>>(std::move(page->second.scripts[id]));
  page->second.scripts[id].clear();
  auto added = std::make_shared<size_t>(0);
  auto on_added = [this, page_id, id, browser, previous, added, done](CefRefPtr<CefDictionaryValue> result) {
    auto page = pages_.find(page_id);
    if (result && result->HasKey("identifier") && page != pages_.end()) {
      page->second.scripts[id].push_back(result->GetString("identifier"));
    }
    if (++*added < 2) return;
    for (const std::string& identifier : *previous) {
      CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
      params->SetString("identifier", identifier);
      devtools_->Call(browser, "Page.removeScriptToEvaluateOnNewDocument", params);
    }
    if (done) done();
  };

  // The content scripts, in the extension's world, in every document from
  // now on.
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("source", content_script);
  params->SetString("worldName", world);
  CefRefPtr<DevToolsClient> devtools = devtools_;
  devtools_->Call(browser, "Page.addScriptToEvaluateOnNewDocument", params,
                  [devtools, browser, world, content_script, on_added](CefRefPtr<CefDictionaryValue> result) {
    LOG_IF(ERROR, !result) << "Couldn't add " << world << " to a page";
    on_added(result);
    // And the document already there, if the page got one before the
    // script was added (the runtime runs once per document, whichever way
    // it's run first).
    EvaluateInWorld(devtools, browser, world, content_script, false, nullptr);
  });

  // The page runtime, in each document's own world (it does nothing but in
  // the extension's pages); and the document already there. The
  // extension's page there started without it (a page opened by a page
  // isn't held back for it, see BrowserManager::CreatePageView), so its
  // scripts have run without `openp41ge`: it loads again, with it.
  params = CefDictionaryValue::Create();
  params->SetString("source", page_script);
  const std::string origin = extension_scheme::Origin(id);
  devtools_->Call(browser, "Page.addScriptToEvaluateOnNewDocument", params,
                  [devtools, browser, origin, on_added](CefRefPtr<CefDictionaryValue> result) {
    on_added(result);
    if (!result) return;
    devtools->Evaluate(browser,
                       "location.origin === " + JsonString(origin) +
                           " && !document.openp41geExtensionRan && location.reload()",
                       {});
  });
}

CefRefPtr<CefDictionaryValue> ExtensionManager::ContentValues(const Loaded& loaded) {
  CefRefPtr<CefDictionaryValue> values = loaded.values->Copy(false);
  CefDictionaryValue::KeyList keys;
  loaded.secrets->GetKeys(keys);
  for (const CefString& key : keys) values->SetString(key, "");
  return values;
}

CefRefPtr<CefDictionaryValue> ExtensionManager::PageValues(const Loaded& loaded) {
  CefRefPtr<CefDictionaryValue> values = loaded.values->Copy(false);
  CefDictionaryValue::KeyList keys;
  loaded.secrets->GetKeys(keys);
  for (const CefString& key : keys) values->SetString(key, loaded.secrets->GetString(key));
  return values;
}

void ExtensionManager::SetValues(Loaded& loaded, CefRefPtr<CefDictionaryValue> values) {
  // Secrets to the SecretStore (one left out, or empty, is deleted); the
  // rest to config.json.
  loaded.values = values->Copy(false);
  loaded.secrets = CefDictionaryValue::Create();
  for (const std::string& key : loaded.secret_keys) {
    const bool set = loaded.values->GetType(key) == VTYPE_STRING && !loaded.values->GetString(key).empty();
    if (set) {
      loaded.secrets->SetString(key, loaded.values->GetString(key));
      secrets_.Set(loaded.extension.id, key, loaded.values->GetString(key));
    } else {
      secrets_.Delete(loaded.extension.id, key);
    }
    loaded.values->Remove(key);
  }
  BuildScripts(loaded);
  CefPostTask(TID_FILE_USER_BLOCKING,
              base::BindOnce(&WriteFile, loaded.data + "/" + kConfigFile, Json(loaded.values)));
  const std::string page_json = Json(PageValues(loaded));
  const std::string content_json = Json(ContentValues(loaded));
  const std::string id = loaded.extension.id;
  const std::string origin = extension_scheme::Origin(id);
  for (auto& [page_id, page] : pages_) {
    if (!page.scripts.count(id)) continue;  // Not in this page (a private one).
    // Later documents get the new values.
    AddScripts(page_id, loaded, nullptr);
    CefRefPtr<CefBrowser> browser = page.browser;
    // The extension's page, if this is one, and its content scripts.
    devtools_->Evaluate(browser,
                        "location.origin === " + JsonString(origin) + " && window.__openp41geSettingsChanged?.(" +
                            page_json + ")",
                        {});
    EvaluateInWorld(devtools_, browser, loaded.world, "globalThis.__openp41geSettingsChanged?.(" + content_json + ")",
                    false, nullptr);
  }
}

void ExtensionManager::SetFeature(Loaded& loaded, const std::string& feature, bool enabled) {
  loaded.features->SetBool(feature, enabled);
  // Only what differs from the default is the user's.
  for (const Extension::Feature& f : loaded.extension.features) {
    if (f.id == feature && f.enabled_by_default == enabled) loaded.features->Remove(feature);
  }
  CefPostTask(TID_FILE_USER_BLOCKING,
              base::BindOnce(&WriteFile, loaded.data + "/" + kFeaturesFile, Json(loaded.features)));
  BuildScripts(loaded);
  const std::string id = loaded.extension.id;
  const std::string states = "{" + JsonString(feature) + ": " + (enabled ? "true" : "false") + "}";
  const std::string origin = extension_scheme::Origin(id);
  for (auto& [page_id, page] : pages_) {
    if (!page.scripts.count(id)) continue;
    // Later documents as the user set it; and the open ones told.
    AddScripts(page_id, loaded, nullptr);
    EvaluateInWorld(devtools_, page.browser, loaded.world, "globalThis.__openp41geFeaturesChanged?.(" + states + ")",
                    false, nullptr);
    devtools_->Evaluate(page.browser,
                        "location.origin === " + JsonString(origin) + " && window.__openp41geFeaturesChanged?.(" +
                            states + ")",
                        {});
  }
}

CefRefPtr<CefValue> ExtensionManager::State() const {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const Loaded& loaded : loaded_) {
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetString("key", loaded.source);
    item->SetString("folder", loaded.source);
    item->SetBool("installed", loaded.installed);
    item->SetBool("enabled", loaded.enabled);
    item->SetString("error", loaded.error);
    if (!loaded.github_repo.empty()) {
      CefRefPtr<CefDictionaryValue> from = CefDictionaryValue::Create();
      from->SetString("repo", loaded.github_repo);
      from->SetString("tag", loaded.github_tag);
      from->SetString("sha256", loaded.github_sha256);
      item->SetDictionary("github", from);
    }
    if (!loaded.update_version.empty()) {
      CefRefPtr<CefDictionaryValue> update = CefDictionaryValue::Create();
      update->SetString("version", loaded.update_version);
      update->SetString("tag", loaded.update_tag);
      item->SetDictionary("update", update);
    }
    if (loaded.error.empty()) {
      const Extension& extension = loaded.extension;
      item->SetString("id", extension.id);
      item->SetString("name", extension.name);
      item->SetString("version", extension.version);
      item->SetString("description", extension.description);
      // The sites it runs on, each once.
      CefRefPtr<CefListValue> sites = CefListValue::Create();
      std::vector<std::string> seen;
      for (const Extension::ContentScript& script : extension.content_scripts) {
        for (const std::string& pattern : script.matches) {
          if (std::find(seen.begin(), seen.end(), pattern) != seen.end()) continue;
          seen.push_back(pattern);
          sites->SetString(sites->GetSize(), pattern);
        }
      }
      item->SetList("sites", sites);
      item->SetList("features", FeatureList(extension, loaded.features));
      // Its settings page: its own, else the browser's if it has settings.
      std::string settings;
      for (const Extension::Page& page : extension.pages) {
        if (page.settings) settings = extension_scheme::Origin(extension.id) + "/" + page.path;
      }
      if (settings.empty() && !extension.config_schema.empty()) settings = extension_scheme::SettingsUrl(extension.id);
      item->SetString("settings", settings);
      // For the page to say whether it needs setup.
      if (!extension.config_schema.empty()) {
        CefRefPtr<CefDictionaryValue> config = CefDictionaryValue::Create();
        config->SetValue("schema", CefParseJSON(extension.config_schema, JSON_PARSER_RFC));
        // Secrets as set or not, not what they are.
        config->SetDictionary("values", ContentValues(loaded));
        item->SetDictionary("config", config);
      }
    }
    list->SetDictionary(list->GetSize(), item);
  }
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetList(list);
  return value;
}

void ExtensionManager::Notify() {
  const std::string state = Json(State());
  for (const Listener& listener : listeners_) listener.callback->Success(state);
}

void ExtensionManager::OnQueryCanceled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int64_t query_id) {
  std::erase_if(listeners_, [&](const Listener& listener) {
    return listener.browser_id == browser->GetIdentifier() && listener.query_id == query_id;
  });
}

void ExtensionManager::OnManagerQuery(CefRefPtr<CefBrowser> browser,
                                      int64_t query_id,
                                      CefRefPtr<CefDictionaryValue> message,
                                      bool persistent,
                                      CefRefPtr<Callback> callback) {
  const std::string type = message->GetString("type");
  // The list, now and after every change.
  if (type == "listen") {
    if (!persistent) {
      callback->Failure(0, "listen is persistent");
      return;
    }
    listeners_.push_back({browser->GetIdentifier(), query_id, callback});
    callback->Success(Json(State()));
    // Updates, when the page opens (at most once an hour).
    if ([NSDate date].timeIntervalSince1970 - last_check_ > 3600) GitHubCheck(nullptr);
    return;
  }
  if (persistent) {
    callback->Failure(0, "Only listen is persistent");
    return;
  }
  if (type == "loadFolder") {
    // The folder the user picks.
    ExtensionManager* self = this;
    browser->GetHost()->RunFileDialog(
        FILE_DIALOG_OPEN_FOLDER, "Load an Extension Folder", "", {},
        new FolderChosen([self, callback](const std::string& folder) {
          if (folder.empty()) {
            callback->Success("");
            return;
          }
          if (Loaded* known = self->FindSource(folder)) {
            callback->Failure(0, "It's loaded already" + (known->error.empty() ? "" : " (with a problem: " + known->error + ")"));
            return;
          }
          Loaded& loaded = self->Add(folder, /*installed=*/true, /*enabled=*/true);
          if (!loaded.error.empty()) {
            const std::string error = loaded.error;
            self->loaded_.pop_back();
            callback->Failure(0, error);
            return;
          }
          self->SaveInstalled();
          self->Notify();
          callback->Success("");
        }));
    return;
  }
  if (type == "githubFind") {
    GitHubFind(message->GetString("repo"), callback);
    return;
  }
  if (type == "githubPrepare") {
    GitHubPrepare(message->GetString("repo"), message->GetString("id"), "", callback);
    return;
  }
  if (type == "githubCheck") {
    GitHubCheck([callback](int found) { callback->Success(std::to_string(found)); });
    return;
  }
  if (type == "githubInstall") {
    GitHubInstall(message->GetString("token"), callback);
    return;
  }
  if (type == "githubCancel") {
    auto it = pending_.find(message->GetString("token"));
    if (it != pending_.end()) {
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, it->second.folder));
      pending_.erase(it);
    }
    callback->Success("");
    return;
  }
  Loaded* loaded = FindSource(message->GetString("key"));
  if (!loaded) {
    callback->Failure(0, "No such extension");
    return;
  }
  if (type == "setEnabled") {
    const bool enabled = message->GetBool("enabled");
    if (loaded->enabled != enabled) {
      if (loaded->active()) Deactivate(*loaded);
      loaded->enabled = enabled;
      if (loaded->active()) Activate(*loaded);
      if (loaded->installed) SaveInstalled();
    }
  } else if (type == "setFeature") {
    const std::string feature = message->GetString("feature");
    bool known = false;
    for (const Extension::Feature& f : loaded->extension.features) known |= f.id == feature;
    if (!loaded->error.empty() || !known) {
      callback->Failure(0, "No such feature");
      return;
    }
    SetFeature(*loaded, feature, message->GetBool("enabled"));
  } else if (type == "reload") {
    // Its folder read again; pages loaded from now on get it.
    if (loaded->active()) Deactivate(*loaded);
    Load(*loaded);
    if (loaded->active()) Activate(*loaded);
  } else if (type == "remove") {
    if (loaded->active()) Deactivate(*loaded);
    // Its settings, secrets and feature switches go with it; and its files,
    // if the browser unpacked them (a GitHub install).
    if (loaded->error.empty()) {
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, loaded->data));
      for (const std::string& key : loaded->secret_keys) secrets_.Delete(loaded->extension.id, key);
    }
    if (!loaded->github_repo.empty()) CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, loaded->source));
    const bool installed = loaded->installed;
    loaded_.remove_if([&](const Loaded& l) { return &l == loaded; });
    if (installed) SaveInstalled();
  } else if (type == "githubUpdate") {
    if (loaded->github_repo.empty() || loaded->update_version.empty() || !loaded->error.empty()) {
      callback->Failure(0, "No update to install");
      return;
    }
    GitHubPrepare(loaded->github_repo, loaded->extension.id, loaded->source, callback);
    return;
  } else if (type == "openSettings") {
    std::string url;
    for (const Extension::Page& page : loaded->extension.pages) {
      if (page.settings) url = extension_scheme::Origin(loaded->extension.id) + "/" + page.path;
    }
    if (url.empty() && !loaded->extension.config_schema.empty()) url = extension_scheme::SettingsUrl(loaded->extension.id);
    if (url.empty() || !loaded->active()) {
      callback->Failure(0, "No settings to open");
      return;
    }
    open_tab_(browser, url);
  } else {
    callback->Failure(0, "Unknown message");
    return;
  }
  Notify();
  callback->Success("");
}

bool ExtensionManager::OnQuery(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               int64_t query_id,
                               const CefString& request,
                               bool persistent,
                               CefRefPtr<Callback> callback) {
  CEF_REQUIRE_UI_THREAD();
  // The Extensions page.
  if (frame && frame->IsMain() && ui_scheme::IsExtensionsUrl(frame->GetURL())) {
    CefRefPtr<CefValue> parsed = CefParseJSON(request, JSON_PARSER_RFC);
    CefRefPtr<CefDictionaryValue> message = parsed ? parsed->GetDictionary() : nullptr;
    if (!message) return false;
    OnManagerQuery(browser, query_id, message, persistent, callback);
    return true;
  }
  // Only from the main frame of a loaded extension's page.
  Loaded* loaded = frame && frame->IsMain() ? Find(extension_scheme::IdOf(frame->GetURL())) : nullptr;
  if (!loaded || persistent) return false;
  CefRefPtr<CefValue> parsed = CefParseJSON(request, JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> message = parsed ? parsed->GetDictionary() : nullptr;
  const std::string type = message ? message->GetString("type").ToString() : std::string();

  if (type == "config.set") {
    // Checked against the schema in the page; here, only that it's an
    // object (the runtimes leave out any value that doesn't fit).
    if (message->GetType("values") != VTYPE_DICTIONARY) {
      callback->Failure(0, "The settings must be an object");
      return true;
    }
    if (loaded->extension.config_schema.empty()) {
      callback->Failure(0, "This extension has no settings");
      return true;
    }
    SetValues(*loaded, message->GetDictionary("values"));
    callback->Success("");
    return true;
  }

  if (type == "openPage") {
    const std::string path = message->GetString("path");
    for (const Extension::Page& page : loaded->extension.pages) {
      if (page.path != path) continue;
      open_tab_(browser, extension_scheme::Origin(loaded->extension.id) + "/" + path);
      callback->Success("");
      return true;
    }
    callback->Failure(0, "No page \"" + path + "\" in the extension's manifest");
    return true;
  }

  if (type == "broadcast") {
    Broadcast(*loaded, message->GetString("feature"), message->GetValue("message"), browser->GetIdentifier(),
              [callback](CefRefPtr<CefListValue> replies) {
                CefRefPtr<CefValue> value = CefValue::Create();
                value->SetList(replies);
                callback->Success(Json(value));
              });
    return true;
  }

  callback->Failure(0, "Unknown message");
  return true;
}

void ExtensionManager::OnBindingCalled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> params) {
  // Which extension's world: the binding is only in its own.
  Loaded* loaded = nullptr;
  for (Loaded& candidate : loaded_) {
    if (candidate.binding == params->GetString("name").ToString()) loaded = &candidate;
  }
  if (!loaded || !pages_.count(browser->GetIdentifier())) return;
  const int context = params->GetInt("executionContextId");
  CefRefPtr<CefValue> parsed = CefParseJSON(params->GetString("payload"), JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> message = parsed ? parsed->GetDictionary() : nullptr;
  if (!message) return;
  const std::string id = Json(message->GetValue("id"));
  // Answers the request in the world that sent it.
  CefRefPtr<DevToolsClient> devtools = devtools_;
  auto reply = [devtools, browser, context, id](bool ok, CefRefPtr<CefValue> value) {
    CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
    params->SetString("expression", "globalThis.__openp41geReply?.(" + id + ", " + (ok ? "true" : "false") + ", " +
                                        (value ? Json(value) : "null") + ")");
    params->SetInt("contextId", context);
    devtools->Call(browser, "Runtime.evaluate", params);
  };
  auto refuse = [reply](const std::string& why) {
    CefRefPtr<CefValue> value = CefValue::Create();
    value->SetString(why);
    reply(false, value);
  };
  const std::string type = message->GetString("type");

  if (type == "openPage") {
    const std::string path = message->GetString("path");
    for (const Extension::Page& page : loaded->extension.pages) {
      if (page.path != path) continue;
      open_tab_(browser, extension_scheme::Origin(loaded->extension.id) + "/" + path);
      reply(true, nullptr);
      return;
    }
    refuse("No page \"" + path + "\" in the extension's manifest");
    return;
  }

  if (type == "broadcast") {
    Broadcast(*loaded, message->GetString("feature"), message->GetValue("message"), browser->GetIdentifier(),
              [reply](CefRefPtr<CefListValue> replies) {
                CefRefPtr<CefValue> value = CefValue::Create();
                value->SetList(replies);
                reply(true, value);
              });
    return;
  }

  refuse("Unknown message");
}

void ExtensionManager::Broadcast(const Loaded& loaded,
                                 const std::string& feature,
                                 CefRefPtr<CefValue> message,
                                 int sender_page,
                                 std::function<void(CefRefPtr<CefListValue>)> done) {
  struct State {
    CefRefPtr<CefListValue> replies = CefListValue::Create();
    size_t waiting = 0;
    bool finished = false;
    std::function<void(CefRefPtr<CefListValue>)> done;
  };
  auto state = std::make_shared<State>();
  state->done = std::move(done);
  auto finish = [state] {
    if (state->finished) return;
    state->finished = true;
    state->done(state->replies);
  };
  auto collect = [state, finish](CefRefPtr<CefValue> value) {
    if (value && value->GetType() == VTYPE_LIST) {
      CefRefPtr<CefListValue> list = value->GetList();
      for (size_t i = 0; i < list->GetSize(); ++i) {
        state->replies->SetValue(state->replies->GetSize(), list->GetValue(i)->Copy());
      }
    }
    if (--state->waiting == 0) finish();
  };
  if (feature.empty() || !message) {
    finish();
    return;
  }
  const std::string call = "(" + JsonString(feature) + ", " + Json(message) + ")";
  const std::string origin = extension_scheme::Origin(loaded.extension.id);
  DevToolsClient::EvaluateOptions awaited;
  awaited.await_promise = true;
  // The feature in the extension's content scripts in the other tabs, and
  // the extension's other pages.
  for (auto& [page_id, page] : pages_) {
    if (page_id == sender_page || !page.scripts.count(loaded.extension.id)) continue;
    state->waiting += 2;
    EvaluateInWorld(devtools_, page.browser, loaded.world, "globalThis.__openp41geDeliver?.(" + call.substr(1), true,
                    collect);
    devtools_->Evaluate(page.browser,
                        "location.origin === " + JsonString(origin) + " ? window.__openp41geDeliver?.(" +
                            call.substr(1) + " : undefined",
                        awaited, collect);
  }
  if (state->waiting == 0) {
    CefPostTask(TID_UI, base::BindOnce([](std::function<void()> finish) { finish(); }, std::function<void()>(finish)));
    return;
  }
  // Whatever has answered by then.
  CefPostDelayedTask(TID_UI, base::BindOnce([](std::function<void()> finish) { finish(); }, std::function<void()>(finish)),
                     kBroadcastTimeoutMs);
}

void ExtensionManager::GitHubFind(const std::string& text, CefRefPtr<Callback> callback) {
  const std::string repo = github::ParseRepo(text);
  if (repo.empty()) {
    callback->Failure(0, "That isn't a GitHub repo: give owner/repo, or its github.com address");
    return;
  }
  github::ListExtensions(repo, [repo, callback](std::vector<github::Release> releases, std::string error) {
    if (!error.empty()) {
      callback->Failure(0, "Couldn't find extensions: " + error);
      return;
    }
    CefRefPtr<CefListValue> list = CefListValue::Create();
    for (const github::Release& release : releases) {
      CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
      item->SetString("id", release.id);
      item->SetString("version", release.version);
      item->SetString("tag", release.tag);
      list->SetDictionary(list->GetSize(), item);
    }
    CefRefPtr<CefDictionaryValue> found = CefDictionaryValue::Create();
    found->SetString("repo", repo);
    found->SetList("extensions", list);
    callback->Success(Json(found));
  });
}

void ExtensionManager::GitHubPrepare(const std::string& text,
                                     const std::string& id,
                                     const std::string& update_key,
                                     CefRefPtr<Callback> callback) {
  const std::string repo = github::ParseRepo(text);
  if (repo.empty()) {
    callback->Failure(0, "That isn't a GitHub repo");
    return;
  }
  for (const Loaded& loaded : loaded_) {
    if (update_key.empty() && loaded.error.empty() && loaded.extension.id == id) {
      callback->Failure(0, "An extension with the id \"" + id + "\" is installed already");
      return;
    }
  }
  ExtensionManager* self = this;
  // The release again (it may have changed since the list), then its zip.
  github::ListExtensions(repo, [self, repo, id, update_key, callback](std::vector<github::Release> releases,
                                                                      std::string error) {
    const github::Release* release = nullptr;
    for (const github::Release& r : releases) {
      if (r.id == id) release = &r;
    }
    if (!release) {
      callback->Failure(0, error.empty() ? "No release of \"" + id + "\" in " + repo : "Couldn't find it: " + error);
      return;
    }
    const github::Release chosen = *release;
    github::Download(chosen.asset_url, kMaxPackageBytes, [self, repo, chosen, update_key, callback](std::string zip,
                                                                                                     std::string error) {
      if (!error.empty()) {
        callback->Failure(0, "Couldn't download " + chosen.asset + ": " + error);
        return;
      }
      const std::string sha256 = extension_package::Sha256(zip);
      const std::string token = std::to_string(++self->staged_) + "-" + sha256.substr(0, 12);
      const std::string folder = self->data_folder_ + "/" + kStagingFolder + "/" + token;
      // Unpacked off the UI thread, then checked as a folder is.
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(
          [](ExtensionManager* self, std::string zip, std::string folder, std::string token, std::string repo,
             github::Release chosen, std::string sha256, std::string update_key, CefRefPtr<Callback> callback) {
            std::string problem = extension_package::Unpack(zip, folder);
            CefPostTask(TID_UI, base::BindOnce(
                [](ExtensionManager* self, std::string problem, std::string folder, std::string token,
                   std::string repo, github::Release chosen, std::string sha256, std::string update_key,
                   CefRefPtr<Callback> callback) {
                  std::string error = problem;
                  std::optional<Extension> extension;
                  if (error.empty()) extension = extensions::Load(folder, &error);
                  if (extension && extension->id != chosen.id) {
                    error = "its manifest's id is \"" + extension->id + "\", not \"" + chosen.id + "\"";
                  }
                  if (!error.empty()) {
                    CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, folder));
                    callback->Failure(0, "Not installed: " + error);
                    return;
                  }
                  // An update: the extension it updates, still there and older.
                  Loaded* current = update_key.empty() ? nullptr : self->FindSource(update_key);
                  if (!update_key.empty() &&
                      (!current || !current->error.empty() ||
                       !github::IsNewer(extension->version, current->extension.version))) {
                    CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, folder));
                    callback->Failure(0, "No newer version to update to");
                    return;
                  }
                  self->pending_[token] = {repo, chosen.tag, sha256, extension->id, extension->version, folder,
                                           update_key};
                  // What the user reviews.
                  CefRefPtr<CefDictionaryValue> review = CefDictionaryValue::Create();
                  review->SetString("token", token);
                  review->SetString("repo", repo);
                  review->SetString("tag", chosen.tag);
                  review->SetString("sha256", sha256);
                  review->SetString("id", extension->id);
                  review->SetString("name", extension->name);
                  review->SetString("version", extension->version);
                  review->SetString("description", extension->description);
                  std::vector<std::string> patterns;
                  for (const Extension::ContentScript& script : extension->content_scripts) {
                    patterns.insert(patterns.end(), script.matches.begin(), script.matches.end());
                  }
                  CefRefPtr<CefListValue> sites = CefListValue::Create();
                  for (const std::string& pattern : patterns) sites->SetString(sites->GetSize(), pattern);
                  review->SetList("sites", sites);  // (Owned by `review` now: `sites` is spent.)
                  if (current) {
                    // The sites it would run on that the installed version doesn't.
                    std::vector<std::string> old_sites;
                    for (const Extension::ContentScript& script : current->extension.content_scripts) {
                      old_sites.insert(old_sites.end(), script.matches.begin(), script.matches.end());
                    }
                    CefRefPtr<CefListValue> new_sites = CefListValue::Create();
                    for (const std::string& pattern : patterns) {
                      if (std::find(old_sites.begin(), old_sites.end(), pattern) == old_sites.end()) {
                        new_sites->SetString(new_sites->GetSize(), pattern);
                      }
                    }
                    review->SetBool("update", true);
                    review->SetString("from", current->extension.version);
                    review->SetList("newSites", new_sites);
                  }
                  CefRefPtr<CefListValue> features = CefListValue::Create();
                  for (const Extension::Feature& feature : extension->features) {
                    features->SetString(features->GetSize(), feature.name);
                  }
                  review->SetList("features", features);
                  if (!extension->config_schema.empty()) {
                    review->SetValue("config", CefParseJSON(extension->config_schema, JSON_PARSER_RFC));
                  }
                  callback->Success(Json(review));
                },
                self, problem, folder, token, repo, chosen, sha256, update_key, callback));
          },
          self, std::move(zip), folder, token, repo, chosen, sha256, update_key, callback));
    });
  });
}

void ExtensionManager::GitHubInstall(const std::string& token, CefRefPtr<Callback> callback) {
  auto it = pending_.find(token);
  if (it == pending_.end()) {
    callback->Failure(0, "Nothing to install: download it again");
    return;
  }
  const Pending pending = it->second;
  pending_.erase(it);
  if (!pending.update_key.empty()) {
    // An update: the new version's files in place of the old's; the user's
    // side (settings, secrets, switches: by id) stays.
    Loaded* loaded = FindSource(pending.update_key);
    if (!loaded || !loaded->error.empty() || loaded->extension.id != pending.id) {
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, pending.folder));
      callback->Failure(0, "The extension it updates has gone");
      return;
    }
    namespace fs = std::filesystem;
    const std::string folder = data_folder_ + "/" + kInstalledFolder + "/" + pending.id + "/" + pending.version;
    std::error_code error;
    fs::remove_all(folder, error);
    fs::create_directories(fs::path(folder).parent_path(), error);
    fs::rename(pending.folder, folder, error);
    if (error) {
      callback->Failure(0, "Couldn't update it: " + error.message());
      return;
    }
    if (loaded->active()) Deactivate(*loaded);
    const std::string old_folder = loaded->source;
    loaded->source = folder;
    Load(*loaded);
    if (!loaded->error.empty()) {
      // The new version doesn't load: back to the old one.
      const std::string why = loaded->error;
      loaded->source = old_folder;
      Load(*loaded);
      if (loaded->active()) Activate(*loaded);
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, folder));
      callback->Failure(0, "Not updated: " + why);
      return;
    }
    if (loaded->active()) Activate(*loaded);
    loaded->github_tag = pending.tag;
    loaded->github_sha256 = pending.sha256;
    loaded->update_version.clear();
    loaded->update_tag.clear();
    if (old_folder != folder) CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, old_folder));
    SaveInstalled();
    Notify();
    callback->Success(JsonString(loaded->source));
    return;
  }
  for (const Loaded& loaded : loaded_) {
    if (loaded.error.empty() && loaded.extension.id == pending.id) {
      CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, pending.folder));
      callback->Failure(0, "An extension with the id \"" + pending.id + "\" is installed already");
      return;
    }
  }
  // From staging to installed/<id>/<version>.
  namespace fs = std::filesystem;
  const std::string folder = data_folder_ + "/" + kInstalledFolder + "/" + pending.id + "/" + pending.version;
  std::error_code error;
  fs::remove_all(folder, error);
  fs::create_directories(fs::path(folder).parent_path(), error);
  fs::rename(pending.folder, folder, error);
  if (error) {
    callback->Failure(0, "Couldn't install it: " + error.message());
    return;
  }
  Loaded& loaded = Add(folder, /*installed=*/true, /*enabled=*/true);
  loaded.github_repo = pending.repo;
  loaded.github_tag = pending.tag;
  loaded.github_sha256 = pending.sha256;
  if (!loaded.error.empty()) {
    const std::string why = loaded.error;
    loaded_.pop_back();
    callback->Failure(0, "Not installed: " + why);
    return;
  }
  SaveInstalled();
  Notify();
  callback->Success(JsonString(loaded.source));
}

void ExtensionManager::GitHubCheck(std::function<void(int found)> done) {
  last_check_ = [NSDate date].timeIntervalSince1970;
  // Each repo once.
  std::vector<std::string> repos;
  for (const Loaded& loaded : loaded_) {
    if (!loaded.github_repo.empty() &&
        std::find(repos.begin(), repos.end(), loaded.github_repo) == repos.end()) {
      repos.push_back(loaded.github_repo);
    }
  }
  auto waiting = std::make_shared<size_t>(repos.size());
  auto found = std::make_shared<int>(0);
  auto finish = [this, done, found] {
    Notify();
    if (done) done(*found);
  };
  if (repos.empty()) {
    finish();
    return;
  }
  for (const std::string& repo : repos) {
    github::ListExtensions(repo, [this, repo, waiting, found, finish](std::vector<github::Release> releases,
                                                                       std::string error) {
      LOG_IF(WARNING, !error.empty()) << "Couldn't check " << repo << " for updates: " << error;
      for (Loaded& loaded : loaded_) {
        if (loaded.github_repo != repo || !loaded.error.empty()) continue;
        for (const github::Release& release : releases) {
          if (release.id != loaded.extension.id) continue;
          if (github::IsNewer(release.version, loaded.extension.version)) {
            loaded.update_version = release.version;
            loaded.update_tag = release.tag;
            ++*found;
          } else {
            loaded.update_version.clear();
            loaded.update_tag.clear();
          }
        }
      }
      if (--*waiting == 0) finish();
    });
  }
}
