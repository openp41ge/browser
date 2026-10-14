// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_

#include <functional>
#include <string>
#include <vector>

#include "include/cef_browser.h"

#include "devtools_client.h"
#include "extensions/extension.h"

// The extensions loaded, and their content scripts in pages. See
// plans/2026-10-14-extension-system.md.
//
// Each extension runs in a JavaScript world of its own in every page (an
// isolated world, as Chrome's content scripts do): the browser registers
// the extension runtime (app/extensions/runtime.js) with the extension's
// files over DevTools, to run at the start of each document, and runs it in
// the page's current one. The runtime decides, in the page, whether any of
// the extension's content scripts match the page's address.
//
// The user's side of each extension is kept in the profile, in
// `openp41ge Extensions/<id>/`, and read as the extension loads:
// - config.json: the user's settings values, only those they set (merged
//   over the schema's defaults by the runtime, in the page).
// - features.json: the features they turned on or off ({ "<id>": bool }),
//   only those; the rest are as `enabledByDefault` says.
//
// For now extensions come only from `--extension-folder=<folder>[:<folder>…]`
// (local folders, for this run). Not in private windows. UI thread.
class ExtensionManager {
 public:
  // `profile_folder`: the profile the user's side is kept in.
  ExtensionManager(CefRefPtr<DevToolsClient> devtools, const std::string& profile_folder);

  // Loads the extension in each folder; one that has a problem isn't
  // loaded, and the problem is logged.
  void LoadFolders(const std::vector<std::string>& folders);

  // Whether there are extensions to add to pages.
  bool HasExtensions() const { return !loaded_.empty(); }

  // A page was created: the extensions' scripts in it, from its current
  // document on. `ready` (optional) runs once they're in place for its
  // next document: a page made to wait (created blank) loads then, so its
  // first page gets them from the start, as every later one does.
  void OnPageCreated(CefRefPtr<CefBrowser> browser, std::function<void()> ready = nullptr);

 private:
  struct Loaded {
    Extension extension;
    std::string world;   // Its isolated world's name.
    std::string script;  // The runtime with the extension's files.
  };

  CefRefPtr<DevToolsClient> devtools_;
  const std::string data_folder_;  // <profile>/openp41ge Extensions.
  std::vector<Loaded> loaded_;
};

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
