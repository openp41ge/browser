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
#include "popout/popout_scripts.h"
#include "ui/ui_scheme.h"

namespace {

constexpr char kDataFolder[] = "openp41ge Extensions";
constexpr char kInstalledFile[] = "installed.json";
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
    : devtools_(devtools), data_folder_(profile_folder + "/" + kDataFolder), open_tab_(std::move(open_tab)) {
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
    Add(item->GetString("folder"), /*installed=*/true,
        item->GetType("enabled") != VTYPE_BOOL || item->GetBool("enabled"));
  }
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
  loaded.content_script = ContentScript(loaded.extension, loaded.features, loaded.values);
  loaded.page_script = PageScript(loaded.extension, loaded.features, loaded.values);
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

void ExtensionManager::SetValues(Loaded& loaded, CefRefPtr<CefDictionaryValue> values) {
  loaded.values = values->Copy(false);
  BuildScripts(loaded);
  const std::string json = Json(loaded.values);
  CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&WriteFile, loaded.data + "/" + kConfigFile, json));
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
                            json + ")",
                        {});
    EvaluateInWorld(devtools_, browser, loaded.world, "globalThis.__openp41geSettingsChanged?.(" + json + ")", false,
                    nullptr);
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
        config->SetDictionary("values", loaded.values->Copy(false));
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
    // Its settings and feature switches go with it.
    if (loaded->error.empty()) CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteFolder, loaded->data));
    const bool installed = loaded->installed;
    loaded_.remove_if([&](const Loaded& l) { return &l == loaded; });
    if (installed) SaveInstalled();
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
