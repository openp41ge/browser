// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_

#include <functional>
#include <map>
#include <string>
#include <vector>

#include "include/cef_browser.h"
#include "include/wrapper/cef_message_router.h"

#include "devtools_client.h"
#include "extensions/extension.h"

// The extensions loaded, their content scripts in pages, and their own
// pages. See plans/2026-10-14-extension-system.md.
//
// Each extension runs in a JavaScript world of its own in every page (an
// isolated world, as Chrome's content scripts do): the browser registers
// the extension runtime (app/extensions/runtime.js) with the extension's
// files over DevTools, to run at the start of each document, and runs it in
// the page's current one. The runtime decides, in the page, whether any of
// the extension's content scripts match the page's address. The extension's
// pages (openp41ge-extension://<id>/, extension_scheme.h) get the page
// runtime (app/extensions/page-runtime.js) the same way, in the page's own
// world, where it does nothing unless the page is the extension's.
//
// The user's side of each extension is kept in the profile, in
// `openp41ge Extensions/<id>/`, and read as the extension loads:
// - config.json: the user's settings values, only those they set (merged
//   over the schema's defaults by the runtime, in the page). The
//   extension's pages change them (openp41ge.config.set): they're saved,
//   the scripts registered in pages are replaced with ones that have the
//   new values, and open pages and content scripts are told.
// - features.json: the features they turned on or off ({ "<id>": bool }),
//   only those; the rest are as `enabledByDefault` says.
//
// Messages from extension pages come through a message router of their own
// (`openp41geExtensionQuery`, renderer_app.cc), handled here: only from the
// main frame of a loaded extension's page, and only about that extension.
// Content scripts send theirs through a DevTools binding added only to
// their extension's world (Runtime.addBinding, one name per extension), so
// the binding says which extension sent it; answers go back by evaluating
// in the context that sent it. Broadcasts (feature hosts, messages.js) are
// delivered to the extension's content scripts in other tabs and its
// pages, and never leave the extension.
//
// For now extensions come only from `--extension-folder=<folder>[:<folder>…]`
// (local folders, for this run). Not in private windows. UI thread.
class ExtensionManager : public CefMessageRouterBrowserSide::Handler {
 public:
  // Opens `url` in a new tab beside `opener`'s.
  using OpenTab = std::function<void(CefRefPtr<CefBrowser> opener, const std::string& url)>;

  // `profile_folder`: the profile the user's side is kept in.
  ExtensionManager(CefRefPtr<DevToolsClient> devtools, const std::string& profile_folder, OpenTab open_tab);

  // Loads the extension in each folder; one that has a problem isn't
  // loaded, and the problem is logged. Serves their pages.
  void LoadFolders(const std::vector<std::string>& folders);

  // Whether there are extensions to add to pages.
  bool HasExtensions() const { return !loaded_.empty(); }

  // A page was created: the extensions' scripts in it, from its current
  // document on. `ready` (optional) runs once they're in place for its
  // next document: a page made to wait (created blank) loads then, so its
  // first page gets them from the start, as every later one does.
  void OnPageCreated(CefRefPtr<CefBrowser> browser, std::function<void()> ready = nullptr);
  // It's closing.
  void OnPageClosed(CefRefPtr<CefBrowser> browser);

  // CefMessageRouterBrowserSide::Handler:
  bool OnQuery(CefRefPtr<CefBrowser> browser,
               CefRefPtr<CefFrame> frame,
               int64_t query_id,
               const CefString& request,
               bool persistent,
               CefRefPtr<Callback> callback) override;

 private:
  struct Loaded {
    Extension extension;
    std::string world;    // Its content scripts' isolated world.
    std::string binding;  // The function that world sends to the browser with.
    std::string data;   // Its folder in the profile.
    CefRefPtr<CefDictionaryValue> features;  // features.json.
    CefRefPtr<CefDictionaryValue> values;    // config.json.
    std::string content_script;  // The runtime with the extension's files.
    std::string page_script;     // The page runtime with the extension.
  };
  // A page's registered scripts, as DevTools identifies them, by extension
  // id.
  struct Page {
    CefRefPtr<CefBrowser> browser;
    std::map<std::string, std::vector<std::string>> scripts;
  };

  Loaded* Find(const std::string& id);
  // (Re)builds `loaded`'s scripts from its extension and the user's side.
  static void BuildScripts(Loaded& loaded);
  // Registers `loaded`'s scripts in the page for its next documents, and
  // runs them in its current one; then `done` (optional). Scripts
  // registered before for the extension are removed once the new ones are
  // in (a document starting in between runs each runtime once all the
  // same).
  void AddScripts(int page_id, const Loaded& loaded, std::function<void()> done);
  // The user's settings changed: saved, scripts replaced, pages told.
  void SetValues(Loaded& loaded, CefRefPtr<CefDictionaryValue> values);
  // A content script's request (Runtime.bindingCalled): openPage, or a
  // broadcast; answered in the world that sent it.
  void OnBindingCalled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> params);
  // Delivers a broadcast of `feature` to the extension's content scripts in
  // every page but `sender_page`, and its pages there; `done` gets their
  // replies (what has answered within kBroadcastTimeoutMs).
  void Broadcast(const Loaded& loaded,
                 const std::string& feature,
                 CefRefPtr<CefValue> message,
                 int sender_page,
                 std::function<void(CefRefPtr<CefListValue>)> done);

  CefRefPtr<DevToolsClient> devtools_;
  const std::string data_folder_;  // <profile>/openp41ge Extensions.
  OpenTab open_tab_;
  std::vector<Loaded> loaded_;
  std::map<int, Page> pages_;  // By browser id.
};

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
