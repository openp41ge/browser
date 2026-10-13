// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
#define OPENP41GE_EXPLORER_BROWSER_MANAGER_H_

#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"

#include "browser_window.h"
#include "devtools_client.h"
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
// - Reopen Closed Tab (Cmd-Shift-T) brings back the last tab or window
//   closed, as Chrome does: a tab where it was, a window with its panes and
//   tabs. Not private ones, nor what closed as the app quit.
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
  // Extra info for a new page: the script it runs before its own (if any),
  // read by the renderer (renderer_app.cc).
  CefRefPtr<CefDictionaryValue> NewPageExtraInfo() const;
  // The private windows' profile, created if there's none.
  CefRefPtr<CefRequestContext> PrivateContext();

  CefRefPtr<DevToolsClient> devtools_;
  CefRefPtr<PopoutController> popout_;
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
  // Whether the popup being created should become the active tab.
  bool popup_foreground_ = true;
  bool closing_ = false;

  IMPLEMENT_REFCOUNTING(BrowserManager);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
