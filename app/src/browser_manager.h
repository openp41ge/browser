// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
#define OPENP41GE_EXPLORER_BROWSER_MANAGER_H_

#include <map>
#include <memory>
#include <set>
#include <string>
#include <variant>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"

#include "browser_window.h"
#include "devtools_client.h"
#include "extensions/extension_manager.h"
#include "history.h"
#include "popout/popout_controller.h"

// The browser's windows, and the client for every page.
//
// - Pages are Alloy-style browser views, each a tab in a pane of a
//   BrowserWindow.
// - Pages' popups (window.open, links to new windows) become tabs beside
//   their opener.
// - A link's context menu opens it in a new tab, window or private window.
// - Element pop-out (PopoutController): while something is popped out, new
//   pages hold autoplay.
// - Extensions (ExtensionManager): their content scripts in every page but
//   private windows'.
// - Reopen Closed Tab (Cmd-Shift-T) brings back the last tab or window
//   closed, as Chrome does: a tab where it was, a window with its panes and
//   tabs. Not private ones, nor what closed as the app quit.
// - The session: the windows open (not private ones) are kept in the
//   profile (session.h), and the next start brings them back, each pane's
//   active tab loading and the others when they're first shown.
// - Private windows: their pages share a profile kept only in memory (a
//   request context with no cache path: cookies, site data, cache), created
//   for the first private window and let go with the last, so nothing of it
//   outlives them. They aren't recorded in History.
class BrowserManager : public CefClient,
                       public CefContextMenuHandler,
                       public CefDisplayHandler,
                       public CefFindHandler,
                       public CefFocusHandler,
                       public CefKeyboardHandler,
                       public CefLifeSpanHandler,
                       public CefLoadHandler,
                       public CefRequestHandler,
                       public PopoutController::Observer {
 public:
  // Menu commands; they act on the active window's active tab.
  enum class Command {
    kNewTab,
    kNewWindow,
    kNewPrivateWindow,
    kCloseTab,
    kCloseWindow,
    kNextTab,
    kPreviousTab,
    kBack,
    kForward,
    kReload,
    kReloadIgnoringCache,
    kZoomIn,
    kZoomOut,
    kZoomReset,
    kDevTools,
    kViewSource,
    kPrint,
    kTogglePopout,
    kReopenClosed,
    kFind,
    kFindNext,
    kFindPrevious,
    kUpdate,
    kAbout,
  };

  BrowserManager();
  static BrowserManager* Get();

  // At startup: the windows open when the app last quit, back; else (or
  // also, given one) a window with `url` (or the start page).
  void Start(const std::string& url);

  // Opens a browser window, with `url` (or the start page).
  void OpenWindow(const std::string& url, bool is_private = false);
  // Opens a browser window at `bounds` (screen) holding `tab`, a tab taken
  // from another window of the same kind (dragged out of it).
  void OpenWindowWithTab(CefRefPtr<Tab> tab, const CefRect& bounds, bool is_private);
  // The frontmost browser window at `screen` (CEF screen coordinates), if any.
  BrowserWindow* WindowAt(const CefPoint& screen) const;
  void Run(Command command);
  bool CanRun(Command command) const;
  // Closes everything; the app quits once every window is gone.
  void CloseAll();
  // The app is quitting, however it was asked to (the menu, the last window
  // closing, SIGTERM): keeps what must be kept, before CEF shuts down.
  void OnMessageLoopEnded();
  bool IsClosing() const { return closing_; }
  // Whether Reopen Closed Tab would bring back a window (for its title).
  bool NextReopenIsWindow() const;

  // A new tab's page, loading `url`; in the private profile if `is_private`.
  CefRefPtr<Tab> CreateTab(const std::string& url, bool is_private);
  // A tab for a page CEF created (a popup).
  CefRefPtr<Tab> AdoptTab(CefRefPtr<CefBrowserView> view);
  // A tab brought back, not loaded yet (Tab::Load).
  CefRefPtr<Tab> SavedTab(const WindowLayout::SavedTab& saved);
  // Loads such a tab: its page, for its address.
  void LoadTab(CefRefPtr<Tab> tab, bool is_private);
  // Something kept in the session changed (a tab, a pane, a window): it's
  // written a moment later.
  void SessionChanged();
  // Takes a picture of `tab`'s page for its preview (tab_previews.h), if it
  // shows (its pane's active tab): now, or once it has drawn.
  void CapturePreview(CefRefPtr<Tab> tab, bool is_private);
  void CapturePreviewSoon(CefRefPtr<Tab> tab);
  PopoutController* popout() const { return popout_.get(); }
  DevToolsClient* devtools() const { return devtools_.get(); }
  History* history() const { return history_.get(); }

  // From BrowserWindow.
  int NewWindowId() { return next_window_id_++; }
  // A tab closed on its own: its address, and where it was.
  void RememberClosedTab(const BrowserWindow* window, const std::string& url, int pane_index, int index, bool pane_closed);
  // A window closed with its tabs.
  void RememberClosedWindow(WindowLayout layout);
  void OnWindowCreated(BrowserWindow* window);
  void OnWindowActivated(BrowserWindow* window);
  void OnWindowDestroyed(BrowserWindow* window);
  // From the page view delegate: a popup's view, to become a tab.
  void OnPopupViewCreated(CefRefPtr<CefBrowserView> opener, CefRefPtr<CefBrowserView> popup);

  // CefClient:
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefFindHandler> GetFindHandler() override { return this; }
  CefRefPtr<CefFocusHandler> GetFocusHandler() override { return this; }
  CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

  // CefDisplayHandler:
  void OnAddressChange(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, const CefString& url) override;
  void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override;
  void OnFaviconURLChange(CefRefPtr<CefBrowser> browser, const std::vector<CefString>& icon_urls) override;

  // CefFocusHandler:
  void OnGotFocus(CefRefPtr<CefBrowser> browser) override;

  // CefKeyboardHandler:
  bool OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                     const CefKeyEvent& event,
                     CefEventHandle os_event,
                     bool* is_keyboard_shortcut) override;

  // CefLifeSpanHandler:
  bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
                     CefRefPtr<CefFrame> frame,
                     int popup_id,
                     const CefString& target_url,
                     const CefString& target_frame_name,
                     WindowOpenDisposition target_disposition,
                     bool user_gesture,
                     const CefPopupFeatures& popup_features,
                     CefWindowInfo& window_info,
                     CefRefPtr<CefClient>& client,
                     CefBrowserSettings& settings,
                     CefRefPtr<CefDictionaryValue>& extra_info,
                     bool* no_javascript_access) override;
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  // CefLoadHandler:
  void OnLoadStart(CefRefPtr<CefBrowser> browser,
                   CefRefPtr<CefFrame> frame,
                   TransitionType transition_type) override;
  void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                            bool is_loading,
                            bool can_go_back,
                            bool can_go_forward) override;

  // CefContextMenuHandler:
  void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           CefRefPtr<CefContextMenuParams> params,
                           CefRefPtr<CefMenuModel> model) override;
  bool OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                            CefRefPtr<CefFrame> frame,
                            CefRefPtr<CefContextMenuParams> params,
                            int command_id,
                            EventFlags event_flags) override;

  // CefFindHandler:
  void OnFindResult(CefRefPtr<CefBrowser> browser,
                    int identifier,
                    int count,
                    const CefRect& selection_rect,
                    int active_match_ordinal,
                    bool final_update) override;

  // CefRequestHandler:
  bool OnOpenURLFromTab(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        const CefString& target_url,
                        WindowOpenDisposition target_disposition,
                        bool user_gesture) override;
  bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                      CefRefPtr<CefFrame> frame,
                      CefRefPtr<CefRequest> request,
                      bool user_gesture,
                      bool is_redirect) override;

 private:
  BrowserWindow* WindowOf(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab = nullptr) const;
  // Opens a link from `browser`'s page as `disposition` says: a new tab
  // (foreground or background) beside its tab, or a new window. False if
  // it's to load in the page itself.
  bool OpenLink(CefRefPtr<CefBrowser> browser, const std::string& url, WindowOpenDisposition disposition);
  // A new page's view, loading `url`; in the private profile if
  // `is_private`.
  CefRefPtr<CefBrowserView> CreatePageView(const std::string& url, bool is_private);
  // Extra info for a new page: the script it runs before its own (if any),
  // read by the renderer (renderer_app.cc).
  CefRefPtr<CefDictionaryValue> NewPageExtraInfo() const;
  // The private windows' profile, created if there's none.
  CefRefPtr<CefRequestContext> PrivateContext();

  CefRefPtr<DevToolsClient> devtools_;
  CefRefPtr<PopoutController> popout_;
  std::unique_ptr<ExtensionManager> extensions_;
  // Pages created blank, and the address each loads once extensions are in
  // place (CreatePageView): by view until created, then by page id. While
  // a page waits, its blank page isn't shown as its tab's.
  std::vector<std::pair<CefRefPtr<CefBrowserView>, std::string>> waiting_to_load_;
  std::map<int, std::pair<CefRefPtr<CefBrowser>, std::string>> waiting_pages_;
  // Pages whose blank page is still in their history (cleared as the real
  // one commits).
  std::set<int> blank_in_history_;
  void LoadWaitingPage(int id);
  bool IsWaiting(CefRefPtr<CefBrowser> browser) const { return waiting_pages_.count(browser->GetIdentifier()) > 0; }
  CefRefPtr<CefBrowserViewDelegate> view_delegate_;
  std::unique_ptr<History> history_;
  CefRefPtr<CefRequestContext> private_context_;  // While there are private windows.
  std::vector<CefRefPtr<BrowserWindow>> windows_;
  BrowserWindow* current_ = nullptr;
  int next_tab_id_ = 1;
  int next_window_id_ = 1;
  // What Reopen Closed Tab brings back, the last closed last.
  struct ClosedTab {
    std::string url;
    int window_id;
    int pane_index;
    int index;
    bool pane_closed;  // It was its pane's last tab.
  };
  std::vector<std::variant<ClosedTab, WindowLayout>> closed_;
  void ReopenClosed();
  // The UI's views and start pages, again (a development build's UI changed).
  void ReloadUi();
  void ShowAbout();
  void Remember(std::variant<ClosedTab, WindowLayout> item);
  // The windows to keep in the session, back to front.
  std::vector<WindowLayout> SessionWindows() const;
  void SaveSession(bool now);
  bool session_save_pending_ = false;
  // Pictures of the tabs showing, every so often.
  void CapturePreviewsLater();
  // Whether the popup being created should become the active tab.
  bool popup_foreground_ = true;
  bool closing_ = false;

  IMPLEMENT_REFCOUNTING(BrowserManager);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
