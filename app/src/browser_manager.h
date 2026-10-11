// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
#define OPENP41GE_EXPLORER_BROWSER_MANAGER_H_

#include <string>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"

#include "browser_window.h"
#include "devtools_client.h"
#include "popout/popout_controller.h"

// The browser's windows, and the client for every page.
//
// - Pages are Alloy-style browser views, each a tab in a pane of a
//   BrowserWindow.
// - Pages' popups (window.open, links to new windows) become tabs beside
//   their opener.
// - Element pop-out (PopoutController): while something is popped out, new
//   pages hold autoplay.
class BrowserManager : public CefClient,
                       public CefDisplayHandler,
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
    kOpenLocation,
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
  };

  BrowserManager();
  static BrowserManager* Get();

  // Opens a browser window, with `url` (or an empty tab and the palette).
  void OpenWindow(const std::string& url);
  void Run(Command command);
  bool CanRun(Command command) const;
  // Closes everything; the app quits once every window is gone.
  void CloseAll();
  bool IsClosing() const { return closing_; }

  // A new tab's page, loading `url`.
  CefRefPtr<Tab> CreateTab(const std::string& url);
  // A tab for a page CEF created (a popup).
  CefRefPtr<Tab> AdoptTab(CefRefPtr<CefBrowserView> view);
  PopoutController* popout() const { return popout_.get(); }

  // From BrowserWindow.
  void OnWindowCreated(BrowserWindow* window);
  void OnWindowActivated(BrowserWindow* window);
  void OnWindowDestroyed(BrowserWindow* window);
  // From the page view delegate: a popup's view, to become a tab.
  void OnPopupViewCreated(CefRefPtr<CefBrowserView> opener, CefRefPtr<CefBrowserView> popup);

  // CefClient:
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

  // CefDisplayHandler:
  void OnAddressChange(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, const CefString& url) override;
  void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override;
  void OnFaviconURLChange(CefRefPtr<CefBrowser> browser, const std::vector<CefString>& icon_urls) override;

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
  void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                            bool is_loading,
                            bool can_go_back,
                            bool can_go_forward) override;

  // CefRequestHandler:
  bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                      CefRefPtr<CefFrame> frame,
                      CefRefPtr<CefRequest> request,
                      bool user_gesture,
                      bool is_redirect) override;

 private:
  BrowserWindow* WindowOf(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab = nullptr) const;
  // Extra info for a new page: the script it runs before its own (if any),
  // read by the renderer (renderer_app.cc).
  CefRefPtr<CefDictionaryValue> NewPageExtraInfo() const;

  CefRefPtr<DevToolsClient> devtools_;
  CefRefPtr<PopoutController> popout_;
  CefRefPtr<CefBrowserViewDelegate> view_delegate_;
  std::vector<CefRefPtr<BrowserWindow>> windows_;
  BrowserWindow* current_ = nullptr;
  int next_tab_id_ = 1;
  // Whether the popup being created should become the active tab.
  bool popup_foreground_ = true;
  bool closing_ = false;

  IMPLEMENT_REFCOUNTING(BrowserManager);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
