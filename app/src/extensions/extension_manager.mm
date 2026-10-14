// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/extension_manager.h"

#import <Foundation/Foundation.h>

#include <memory>

#include "include/base/cef_logging.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "popout/popout_scripts.h"

namespace {

// app/extensions/runtime.js, from the app bundle.
const std::string& Runtime() {
  static const std::string runtime = [] {
    NSString* path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"extensions/runtime.js"];
    NSString* text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    LOG_IF(ERROR, !text) << "Missing the extension runtime: " << path.UTF8String;
    return text ? std::string(text.UTF8String) : std::string();
  }();
  return runtime;
}

std::string Json(CefRefPtr<CefValue> value) {
  return CefWriteJSON(value, JSON_WRITER_DEFAULT).ToString();
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

// The script that runs in each document: the runtime, called with the
// extension (its content scripts, with their CSS), each content script's JS
// files as functions, and packages/popout's core.js as a function.
std::string WorldScript(const Extension& extension) {
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
    // Feature toggles come later; for now a feature is as it is by default.
    bool enabled = true;
    for (const Extension::Feature& feature : extension.features) {
      if (feature.id == script.feature) enabled = feature.enabled_by_default;
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
  CefRefPtr<CefValue> info_value = CefValue::Create();
  info_value->SetDictionary(info);

  return "(" + Runtime() + ")(\n" + Json(info_value) + ",\n" + scripts + ",\n" +
         AsFunction(popout_scripts::Library()) + ");\n";
}

}  // namespace

ExtensionManager::ExtensionManager(CefRefPtr<DevToolsClient> devtools) : devtools_(devtools) {}

void ExtensionManager::LoadFolders(const std::vector<std::string>& folders) {
  for (const std::string& folder : folders) {
    std::string error;
    std::optional<Extension> extension = extensions::Load(folder, &error);
    if (!extension) {
      LOG(ERROR) << "Extension not loaded: " << error;
      continue;
    }
    bool duplicate = false;
    for (const Loaded& other : loaded_) duplicate |= other.extension.id == extension->id;
    if (duplicate) {
      LOG(ERROR) << "Extension not loaded: another extension has the id \"" << extension->id << "\" (" << folder << ")";
      continue;
    }
    LOG(INFO) << "Extension loaded: " << extension->name << " (" << extension->id << " " << extension->version
              << ") from " << extension->folder;
    const std::string world = "openp41ge-extension:" + extension->id;
    const std::string script = WorldScript(*extension);
    loaded_.push_back({std::move(*extension), world, script});
  }
}

void ExtensionManager::OnPageCreated(CefRefPtr<CefBrowser> browser, std::function<void()> ready) {
  CEF_REQUIRE_UI_THREAD();
  if (loaded_.empty()) {
    if (ready) ready();
    return;
  }
  // Scripts added for new documents run only while the page domain is on.
  devtools_->Call(browser, "Page.enable", nullptr);
  // `ready` runs once every extension's script is added.
  auto waiting = std::make_shared<size_t>(loaded_.size());
  for (const Loaded& loaded : loaded_) {
    // Every document from now on.
    CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
    params->SetString("source", loaded.script);
    params->SetString("worldName", loaded.world);
    CefRefPtr<DevToolsClient> devtools = devtools_;
    const std::string world = loaded.world;
    const std::string script = loaded.script;
    devtools_->Call(browser, "Page.addScriptToEvaluateOnNewDocument", params,
                    [devtools, browser, world, script, waiting, ready](CefRefPtr<CefDictionaryValue> result) {
      LOG_IF(ERROR, !result) << "Couldn't add " << world << " to a page";
      if (--*waiting == 0 && ready) ready();
      // And the document already there, if the page got one before the
      // script was added (the runtime runs once per document, whichever
      // way it's run first).
      devtools->Call(browser, "Page.getFrameTree", nullptr,
                     [devtools, browser, world, script](CefRefPtr<CefDictionaryValue> tree) {
        CefRefPtr<CefDictionaryValue> frame_tree = tree ? tree->GetDictionary("frameTree") : nullptr;
        CefRefPtr<CefDictionaryValue> frame = frame_tree ? frame_tree->GetDictionary("frame") : nullptr;
        if (!frame) return;
        CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
        params->SetString("frameId", frame->GetString("id"));
        params->SetString("worldName", world);
        devtools->Call(browser, "Page.createIsolatedWorld", params,
                       [devtools, browser, script](CefRefPtr<CefDictionaryValue> created) {
          if (!created || !created->HasKey("executionContextId")) return;
          CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
          params->SetString("expression", script);
          params->SetInt("contextId", created->GetInt("executionContextId"));
          devtools->Call(browser, "Runtime.evaluate", params);
        });
      });
    });
  }
}
