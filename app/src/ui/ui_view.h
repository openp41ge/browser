// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_UI_VIEW_H_
#define OPENP41GE_EXPLORER_UI_UI_VIEW_H_

#include <string>
#include <vector>

#include "include/cef_client.h"
#include "include/views/cef_browser_view.h"
#include "include/wrapper/cef_message_router.h"

// A piece of the browser's own UI: web content from openp41ge://ui/ (app/ui)
// in an Alloy-style browser view (the top bar, a pane's tab bar, the command
// palette).
//
// It talks to the browser over CEF's message router (`cefQuery`, see
// app/ui/channel.js): the page sends messages ({"type": "…", …}), and keeps
// one persistent query open ({"type": "listen"}) to receive the browser's.
// Only openp41ge://ui/ pages get the channel (renderer_app.cc), and this
// view never navigates anywhere else.
class UiView : public CefClient,
               public CefContextMenuHandler,
               public CefDragHandler,
               public CefLifeSpanHandler,
               public CefRequestHandler,
               public CefMessageRouterBrowserSide::Handler {
 public:
  enum class Background { kGutter, kSurface };

  // `page` is a file in app/ui, e.g. "topbar.html". `height` is the view's
  // preferred height, or 0 to fill whatever space its layout gives it.
  UiView(std::string page, int height, Background background);

  // The view, created on first call.
  CefRefPtr<CefBrowserView> view();
  CefRefPtr<CefBrowser> browser() const { return view_ ? view_->GetBrowser() : nullptr; }
  // Sends a message to the page (dropped until the page is listening).
  void Send(CefRefPtr<CefDictionaryValue> message);
  bool connected() const { return listener_ != nullptr; }

  // CefClient:
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override { return this; }
  CefRefPtr<CefDragHandler> GetDragHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
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

  // CefDragHandler:
  void OnDraggableRegionsChanged(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 const std::vector<CefDraggableRegion>& regions) override;

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
  std::string url_;
  int height_;
  Background background_;
  CefRefPtr<CefBrowserView> view_;
  CefRefPtr<CefMessageRouterBrowserSide> router_;
  CefRefPtr<Callback> listener_;
  int64_t listener_id_ = 0;
};

#endif  // OPENP41GE_EXPLORER_UI_UI_VIEW_H_
