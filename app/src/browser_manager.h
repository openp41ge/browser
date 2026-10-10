// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
#define OPENP41GE_EXPLORER_BROWSER_MANAGER_H_

#include <string>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"

#include "devtools_client.h"
#include "page_window.h"
#include "popout/popout_controller.h"

// The browser's pages and their windows, and the client for every page.
//
// - Each page is a Chrome-style browser view in its own window (PageWindow).
// - New tabs and windows, from links, scripts or commands, open as new page
//   windows.
// - Element pop-out (PopoutController): while something is popped out, new
//   pages hold autoplay, and a page only kept open for the pop-out closes
//   with it.
class BrowserManager : public CefClient,
                       public CefLifeSpanHandler,
                       public CefDisplayHandler,
                       public CefCommandHandler,
                       public CefKeyboardHandler,
                       public PopoutController::Observer {
 public:
  BrowserManager();
  static BrowserManager* Get();

  // Opens a page window for `url`.
  void OpenPageWindow(const std::string& url);
  // Opens a page window around a browser view CEF created (a popup).
  void OpenPageWindow(CefRefPtr<CefBrowserView> view);

  // The page of the last active page window.
  CefRefPtr<CefBrowser> CurrentPage() const;
  void ExecuteChromeCommand(int command_id);
  void CloseCurrentWindow();
  // Closes everything; the app quits once every window is gone.
  void CloseAll();
  bool IsClosing() const { return closing_; }

  PopoutController* popout() const { return popout_.get(); }
  void TogglePopout();

  // From PageWindow.
  void OnPageWindowCreated(PageWindow* page_window);
  void OnPageWindowActivated(PageWindow* page_window);
  void OnPageWindowDestroyed(PageWindow* page_window);

  // CefClient:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefCommandHandler> GetCommandHandler() override { return this; }
  CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override { return this; }

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
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  // CefDisplayHandler:
  void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override;

  // CefCommandHandler:
  bool OnChromeCommand(CefRefPtr<CefBrowser> browser,
                       int command_id,
                       cef_window_open_disposition_t disposition) override;

  // CefKeyboardHandler:
  bool OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                     const CefKeyEvent& event,
                     CefEventHandle os_event,
                     bool* is_keyboard_shortcut) override;

  // PopoutController::Observer:
  void OnPopoutClosed(CefRefPtr<CefBrowser> source) override;

 private:
  PageWindow* PageWindowFor(CefRefPtr<CefBrowser> browser) const;
  // Extra info for a new page: the script it runs before its own (if any),
  // read by the renderer (renderer_app.cc).
  CefRefPtr<CefDictionaryValue> NewPageExtraInfo() const;

  CefRefPtr<DevToolsClient> devtools_;
  CefRefPtr<PopoutController> popout_;
  CefRefPtr<PageViewDelegate> view_delegate_;
  std::vector<CefRefPtr<PageWindow>> windows_;
  PageWindow* current_ = nullptr;
  bool closing_ = false;

  IMPLEMENT_REFCOUNTING(BrowserManager);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_MANAGER_H_
