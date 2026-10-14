// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_

#include <functional>
#include <list>
#include <map>
#include <string>
#include <vector>

#include "include/cef_browser.h"
#include "include/wrapper/cef_message_router.h"

#include "devtools_client.h"
#include "extensions/extension.h"
#include "extensions/secret_store.h"

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
// - Secret settings ("secret": true) aren't in a file: they're in the
//   SecretStore (the Keychain), given to the extension's pages but never to
//   its content scripts. One found in config.json is moved there.
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
// Installed extensions are local folders, remembered in the profile
// (`openp41ge Extensions/installed.json`: each one's folder, and whether
// it's on), or GitHub releases (unpacked into `openp41ge Extensions/
// installed/<id>/<version>`, the repo, tag and zip's SHA-256 pinned in
// installed.json; github.h, package.h); `--extension-folder=<folder>[:
// <folder>…]` adds some for one run.
// The Extensions page (openp41ge://extensions/, app/ui/extensions) lists
// them and manages them through the same channel as extension pages,
// checked by its address: load a folder, switch an extension or a feature
// on or off, reload, remove. A feature switched while pages are open
// starts or stops in them (the runtimes' __openp41geFeaturesChanged); an
// extension switched on or off, reloaded or removed changes the pages
// loaded after that, as in Chrome. Not in private windows. UI thread.
class ExtensionManager : public CefMessageRouterBrowserSide::Handler {
 public:
  // Opens `url` in a new tab beside `opener`'s.
  using OpenTab = std::function<void(CefRefPtr<CefBrowser> opener, const std::string& url)>;

  // `profile_folder`: the profile the user's side is kept in.
  ExtensionManager(CefRefPtr<DevToolsClient> devtools, const std::string& profile_folder, OpenTab open_tab);

  // Loads the installed extensions, and the ones in `folders` for this run
  // only. One that has a problem isn't loaded, and the problem is logged
  // (and shown on the Extensions page). Serves their pages.
  void Start(const std::vector<std::string>& folders);

  // Whether there are extensions to add to pages.
  bool HasExtensions() const;

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
  void OnQueryCanceled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int64_t query_id) override;

 private:
  // An extension the browser knows: installed, or for this run. One whose
  // folder didn't load has only `source`, `installed`, `enabled` and
  // `error`.
  struct Loaded {
    std::string source;      // Its folder, as installed (or given).
    bool installed = false;  // Remembered in the profile (else this run only).
    bool enabled = true;     // The user's switch for the whole extension.
    std::string error;       // Why it isn't loaded, or empty.
    // Installed from GitHub: the repo ("owner/repo"), the release's tag and
    // the zip's SHA-256 (pinned); empty for a local folder.
    std::string github_repo, github_tag, github_sha256;
    bool active() const { return error.empty() && enabled; }
    Extension extension;
    std::string world;    // Its content scripts' isolated world.
    std::string binding;  // The function that world sends to the browser with.
    std::string data;   // Its folder in the profile.
    CefRefPtr<CefDictionaryValue> features;  // features.json.
    CefRefPtr<CefDictionaryValue> values;    // config.json (never secrets).
    // Its secret settings' keys (top-level "secret": true), and the ones the
    // user set (from the SecretStore).
    std::vector<std::string> secret_keys;
    CefRefPtr<CefDictionaryValue> secrets;
    std::string content_script;  // The runtime with the extension's files.
    std::string page_script;     // The page runtime with the extension.
  };
  // A page's registered scripts, as DevTools identifies them, by extension
  // id.
  struct Page {
    CefRefPtr<CefBrowser> browser;
    bool domains = false;  // Page and Runtime enabled (once an extension is).
    std::map<std::string, std::vector<std::string>> scripts;
  };
  // An Extensions page listening for the list.
  struct Listener {
    int browser_id;
    int64_t query_id;
    CefRefPtr<Callback> callback;
  };

  // The active extension with `id`.
  Loaded* Find(const std::string& id);
  // The extension (active or not) whose folder is `source`.
  Loaded* FindSource(const std::string& source);
  // Adds the extension in `source`, loading it (on a problem, an entry
  // with its error, logged); serves it and adds it to pages if active.
  Loaded& Add(const std::string& source, bool installed, bool enabled);
  // Loads `loaded`'s folder (again): its manifest and files, and the
  // user's side; sets `error` if it can't.
  void Load(Loaded& loaded);
  // Serves an active extension and adds it to every page; or the reverse.
  void Activate(Loaded& loaded);
  void Deactivate(Loaded& loaded);
  // Turns the page and runtime domains on in a page (once).
  void EnableDomains(Page& page);
  // Adds an active extension to a page: its binding and scripts.
  void AttachTo(int page_id, const Loaded& loaded, std::function<void()> done);
  // Removes an extension's scripts and binding from a page.
  void DetachFrom(Page& page, const Loaded& loaded);
  // installed.json, from the installed extensions.
  void SaveInstalled();
  // Sends every listening Extensions page the list.
  void Notify();
  CefRefPtr<CefValue> State() const;
  // A message from the Extensions page.
  void OnManagerQuery(CefRefPtr<CefBrowser> browser,
                      int64_t query_id,
                      CefRefPtr<CefDictionaryValue> message,
                      bool persistent,
                      CefRefPtr<Callback> callback);
  // A feature switched: features.json, the scripts, and open pages told.
  void SetFeature(Loaded& loaded, const std::string& feature, bool enabled);

  // Installing from GitHub (the Extensions page's githubFind, githubPrepare,
  // githubInstall, githubCancel): a release downloaded and unpacked into
  // staging, awaiting the user's review, by token.
  struct Pending {
    std::string repo, tag, sha256, id, version, folder;
  };
  void GitHubFind(const std::string& text, CefRefPtr<Callback> callback);
  void GitHubPrepare(const std::string& repo, const std::string& id, CefRefPtr<Callback> callback);
  void GitHubInstall(const std::string& token, CefRefPtr<Callback> callback);
  std::map<std::string, Pending> pending_;
  int staged_ = 0;  // Staging folders made this run.
  // (Re)builds `loaded`'s scripts from its extension and the user's side.
  static void BuildScripts(Loaded& loaded);
  // Registers `loaded`'s scripts in the page for its next documents, and
  // runs them in its current one; then `done` (optional). Scripts
  // registered before for the extension are removed once the new ones are
  // in (a document starting in between runs each runtime once all the
  // same).
  void AddScripts(int page_id, const Loaded& loaded, std::function<void()> done);
  // The user's settings changed: saved (secrets in the SecretStore, the
  // rest in config.json), scripts replaced, pages told.
  void SetValues(Loaded& loaded, CefRefPtr<CefDictionaryValue> values);
  // `loaded`'s values for its content scripts (an empty string for each
  // secret that's set, so a required one counts as set; the runtime drops
  // secrets), or for its pages (with the secrets).
  static CefRefPtr<CefDictionaryValue> ContentValues(const Loaded& loaded);
  static CefRefPtr<CefDictionaryValue> PageValues(const Loaded& loaded);
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
  SecretStore secrets_;
  OpenTab open_tab_;
  std::list<Loaded> loaded_;  // A list: its entries stay put as others come and go.
  std::map<int, Page> pages_;  // By browser id.
  std::vector<Listener> listeners_;
};

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_MANAGER_H_
