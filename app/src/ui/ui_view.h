// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_UI_VIEW_H_
#define OPENP41GE_EXPLORER_UI_UI_VIEW_H_

#include <functional>
#include <string>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"
#include "include/wrapper/cef_message_router.h"

// A piece of the browser's own UI: web content from openp41ge://ui/ (app/ui)
// in an Alloy-style browser view (the top bar, a pane's tab bar).
//
// It talks to the browser over CEF's message router (`cefQuery`, see
// app/ui/channel.js): the page sends messages ({"type": "…", …}), and keeps
// one persistent query open ({"type": "listen"}) to receive the browser's.
// Only openp41ge://ui/ pages get the channel (renderer_app.cc), and this
// view never navigates anywhere else.
class UiView : public CefClient,
               public CefContextMenuHandler,
               public CefDragHandler,
               public CefKeyboardHandler,
               public CefLifeSpanHandler,
               public CefPermissionHandler,
               public CefRequestHandler,
               public CefMessageRouterBrowserSide::Handler {
 public:
  enum class Background { kGutter, kSurface };

  // `page` is a file in app/ui, e.g. "topbar.html". `preferred_size` is what
  // the view asks its layout for (the layout stretches the other way, e.g. a
  // bar's width); CEF ignores a size with a zero side.
  UiView(std::string page, CefSize preferred_size, Background background);
  ~UiView() override;

  // Reloads every UI view's page (a development build's UI changed, see
  // ui_live_reload.h). Each sends its state again once its page listens.
  static void ReloadAll();

  // Keys the browser takes before a UI page sees them (its shortcuts, see
  // BrowserManager::OnPreKeyEvent): true if `handler` took the key.
  using ShortcutHandler = std::function<bool(CefRefPtr<CefBrowser> browser, const CefKeyEvent& event)>;
  static void SetShortcutHandler(ShortcutHandler handler);

  // The view, created on first call.
  CefRefPtr<CefBrowserView> view();
  // A new preferred size (a bar growing, say): its parent lays it out again.
  void SetPreferredSize(CefSize size);
  // Or instead, the page in a native view of our own (`parent`, at `bounds`
  // in it, filling it as it's resized): for a window of our own rather than
  // a CEF window, which macOS draws with rounded corners (see FindBar,
  // MenuWindow). Such a page doesn't close with a CEF window: CloseInWindow
  // closes it and then the window it's in, and the app waits for them
  // (WhenOwnWindowPagesClosed) before it quits.
  void CreateIn(CefWindowHandle parent, const CefRect& bounds);
  void CloseInWindow();
  // Runs `done` once no page made with CreateIn is open (now, if none is).
  static void WhenOwnWindowPagesClosed(std::function<void()> done);
  CefRefPtr<CefBrowser> browser() const { return browser_; }
  // Sends a message to the page (dropped until the page is listening).
  void Send(CefRefPtr<CefDictionaryValue> message);
  bool connected() const { return listener_ != nullptr; }

  // CefClient:
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override { return this; }
  CefRefPtr<CefDragHandler> GetDragHandler() override { return this; }
  CefRefPtr<CefKeyboardHandler> GetKeyboardHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefPermissionHandler> GetPermissionHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefProcessId source_process,
                                CefRefPtr<CefProcessMessage> message) override;

  // CefContextMenuHandler:
  void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           CefRefPtr<CefContextMenuParams> params,
                           CefRefPtr<CefMenuModel> model) override;

  // CefKeyboardHandler:
  bool OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                     const CefKeyEvent& event,
                     CefEventHandle os_event,
                     bool* is_keyboard_shortcut) override;

  // CefDragHandler:
  void OnDraggableRegionsChanged(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 const std::vector<CefDraggableRegion>& regions) override;

  // CefPermissionHandler: the UI may load from the local network (e.g. a
  // tab's favicon on a local site); anything else is refused, unprompted.
  bool OnShowPermissionPrompt(CefRefPtr<CefBrowser> browser,
                              uint64_t prompt_id,
                              const CefString& requesting_origin,
                              uint32_t requested_permissions,
                              CefRefPtr<CefPermissionPromptCallback> callback) override;

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
                     bool* no_javascript_access) override {
    return true;  // The browser's UI opens no windows of its own.
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  // A page made with CreateIn closes the window it's in (CEF would ask it to
  // close itself, which a borderless window can't), and is gone with it.
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  // CefRequestHandler:
  bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                      CefRefPtr<CefFrame> frame,
                      CefRefPtr<CefRequest> request,
                      bool user_gesture,
                      bool is_redirect) override;
  void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                 TerminationStatus status,
                                 int error_code,
                                 const CefString& error_string) override;

  // CefMessageRouterBrowserSide::Handler:
  bool OnQuery(CefRefPtr<CefBrowser> browser,
               CefRefPtr<CefFrame> frame,
               int64_t query_id,
               const CefString& request,
               bool persistent,
               CefRefPtr<Callback> callback) override;
  void OnQueryCanceled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int64_t query_id) override;

 protected:
  // The page started listening (send it the current state).
  virtual void OnConnected() {}
  // A message from the page. Return false if it isn't one this view knows.
  virtual bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) = 0;
  // The page's -webkit-app-region: drag areas changed (view coordinates).
  virtual void OnDragRegions(const std::vector<CefDraggableRegion>& regions) {}

 private:
  static bool IsAt(void* window, const CefPoint& point);
  bool own_window_ = false;      // Made with CreateIn.
  const void* host_window_ = nullptr;  // Its window (an NSWindow, retained) until it's closed.
  bool close_pending_ = false;  // Asked to close before it was made.
  std::string url_;
  CefSize preferred_size_;
  Background background_;
  CefRefPtr<CefBrowserView> view_;
  CefRefPtr<CefBrowserViewDelegate> delegate_;
  CefRefPtr<CefBrowser> browser_;
  CefRefPtr<CefMessageRouterBrowserSide> router_;
  CefRefPtr<Callback> listener_;
  int64_t listener_id_ = 0;
};

#endif  // OPENP41GE_EXPLORER_UI_UI_VIEW_H_
