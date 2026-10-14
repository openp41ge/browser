// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/extension_manager.h"

#import <Foundation/Foundation.h>

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

namespace {

constexpr char kDataFolder[] = "openp41ge Extensions";
constexpr char kConfigFile[] = "config.json";
constexpr char kFeaturesFile[] = "features.json";

// A file in the app bundle's extensions/ folder.
std::string Resource(NSString* name) {
  NSString* path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:name];
  NSString* text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  LOG_IF(ERROR, !text) << "Missing from the app: " << path.UTF8String;
  return text ? std::string(text.UTF8String) : std::string();
}

// app/extensions/runtime.js.
const std::string& Runtime() {
  static const std::string runtime = Resource(@"extensions/runtime.js");
  return runtime;
}

// app/extensions/page-runtime.js.
const std::string& PageRuntime() {
  static const std::string runtime = Resource(@"extensions/page-runtime.js");
  return runtime;
}

// A function's source that returns app/extensions/settings.js's helpers,
// made with the code editor's config logic
// (third_party/openp41ge-uikit/config.js, a script that defines
// `openp41geConfig`).
const std::string& LoadSettings() {
  static const std::string load = "function () {\n" + Resource(@"extensions/config.js") + "\nreturn (" +
                                  Resource(@"extensions/settings.js") + ")(openp41geConfig);\n}";
  return load;
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
    // As the user set its feature, else as it is by default.
    bool enabled = true;
    for (const Extension::Feature& feature : extension.features) {
      if (feature.id != script.feature) continue;
      enabled = feature.enabled_by_default;
      if (features->GetType(feature.id) == VTYPE_BOOL) enabled = features->GetBool(feature.id);
    }
    item->SetBool("enabled", enabled);
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
  // The runtime reads `config` from the extension.
  std::string info_json = Json(info);
  info_json.pop_back();  // The closing brace.
  info_json += ",\"config\":" + ConfigJson(extension, values) + "}";

  return "(" + Runtime() + ")(\n" + info_json + ",\n" + scripts + ",\n" + AsFunction(popout_scripts::Library()) +
         ",\n" + LoadSettings() + ");\n";
}

// The script that runs in each document's own world, for the extension's
// pages: the page runtime, called with the extension, its config and the
// settings helpers.
std::string PageScript(const Extension& extension, CefRefPtr<CefDictionaryValue> values) {
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
  return "(" + PageRuntime() + ")(\n" + Json(info) + ",\n" + ConfigJson(extension, values) + ",\n" +
         LoadSettings() + ");\n";
}

}  // namespace

ExtensionManager::ExtensionManager(CefRefPtr<DevToolsClient> devtools,
                                   const std::string& profile_folder,
                                   OpenTab open_tab)
    : devtools_(devtools), data_folder_(profile_folder + "/" + kDataFolder), open_tab_(std::move(open_tab)) {}

void ExtensionManager::LoadFolders(const std::vector<std::string>& folders) {
  for (const std::string& folder : folders) {
    std::string error;
    std::optional<Extension> extension = extensions::Load(folder, &error);
    if (!extension) {
      LOG(ERROR) << "Extension not loaded: " << error;
      continue;
    }
    if (Find(extension->id)) {
      LOG(ERROR) << "Extension not loaded: another extension has the id \"" << extension->id << "\" (" << folder << ")";
      continue;
    }
    LOG(INFO) << "Extension loaded: " << extension->name << " (" << extension->id << " " << extension->version
              << ") from " << extension->folder;
    Loaded loaded;
    loaded.world = "openp41ge-extension:" + extension->id;
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
    extension_scheme::Serve(loaded.extension, NSBundle.mainBundle.resourcePath.UTF8String);
    loaded_.push_back(std::move(loaded));
  }
}

ExtensionManager::Loaded* ExtensionManager::Find(const std::string& id) {
  for (Loaded& loaded : loaded_) {
    if (loaded.extension.id == id) return &loaded;
  }
  return nullptr;
}

void ExtensionManager::BuildScripts(Loaded& loaded) {
  loaded.content_script = ContentScript(loaded.extension, loaded.features, loaded.values);
  loaded.page_script = PageScript(loaded.extension, loaded.values);
}

void ExtensionManager::OnPageCreated(CefRefPtr<CefBrowser> browser, std::function<void()> ready) {
  CEF_REQUIRE_UI_THREAD();
  if (loaded_.empty()) {
    if (ready) ready();
    return;
  }
  pages_[browser->GetIdentifier()] = {browser, {}};
  // Scripts added for new documents run only while the page domain is on.
  devtools_->Call(browser, "Page.enable", nullptr);
  // `ready` runs once every extension's scripts are added.
  auto waiting = std::make_shared<size_t>(loaded_.size());
  for (const Loaded& loaded : loaded_) {
    AddScripts(browser->GetIdentifier(), loaded, [waiting, ready] {
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
    devtools->Call(browser, "Page.getFrameTree", nullptr,
                   [devtools, browser, world, content_script](CefRefPtr<CefDictionaryValue> tree) {
      CefRefPtr<CefDictionaryValue> frame_tree = tree ? tree->GetDictionary("frameTree") : nullptr;
      CefRefPtr<CefDictionaryValue> frame = frame_tree ? frame_tree->GetDictionary("frame") : nullptr;
      if (!frame) return;
      CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
      params->SetString("frameId", frame->GetString("id"));
      params->SetString("worldName", world);
      devtools->Call(browser, "Page.createIsolatedWorld", params,
                     [devtools, browser, content_script](CefRefPtr<CefDictionaryValue> created) {
        if (!created || !created->HasKey("executionContextId")) return;
        CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
        params->SetString("expression", content_script);
        params->SetInt("contextId", created->GetInt("executionContextId"));
        devtools->Call(browser, "Runtime.evaluate", params);
      });
    });
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
    // Later documents get the new values.
    AddScripts(page_id, loaded, nullptr);
    CefRefPtr<CefBrowser> browser = page.browser;
    // The extension's page, if this is one, and its content scripts.
    devtools_->Evaluate(browser,
                        "location.origin === " + JsonString(origin) + " && window.__openp41geSettingsChanged?.(" +
                            json + ")",
                        {});
    const std::string world = loaded.world;
    CefRefPtr<DevToolsClient> devtools = devtools_;
    devtools_->Call(browser, "Page.getFrameTree", nullptr, [devtools, browser, world, json](CefRefPtr<CefDictionaryValue> tree) {
      CefRefPtr<CefDictionaryValue> frame_tree = tree ? tree->GetDictionary("frameTree") : nullptr;
      CefRefPtr<CefDictionaryValue> frame = frame_tree ? frame_tree->GetDictionary("frame") : nullptr;
      if (!frame) return;
      CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
      params->SetString("frameId", frame->GetString("id"));
      params->SetString("worldName", world);
      devtools->Call(browser, "Page.createIsolatedWorld", params, [devtools, browser, json](CefRefPtr<CefDictionaryValue> created) {
        if (!created || !created->HasKey("executionContextId")) return;
        CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
        params->SetString("expression", "globalThis.__openp41geSettingsChanged?.(" + json + ")");
        params->SetInt("contextId", created->GetInt("executionContextId"));
        devtools->Call(browser, "Runtime.evaluate", params);
      });
    });
  }
}

bool ExtensionManager::OnQuery(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               int64_t query_id,
                               const CefString& request,
                               bool persistent,
                               CefRefPtr<Callback> callback) {
  CEF_REQUIRE_UI_THREAD();
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

  callback->Failure(0, "Unknown message");
  return true;
}
