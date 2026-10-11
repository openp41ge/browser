// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_view.h"

#import <Cocoa/Cocoa.h>

#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "ui/ui_scheme.h"

namespace {

// Alloy style, at the UI's height (0: no preference, fill).
class UiViewDelegate : public CefBrowserViewDelegate {
 public:
  explicit UiViewDelegate(int height) : height_(height) {}
  cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefSize GetPreferredSize(CefRefPtr<CefView> view) override { return CefSize(0, height_); }

 private:
  int height_;
  IMPLEMENT_REFCOUNTING(UiViewDelegate);
};

// The view's colour before its page has painted (openp41ge's tokens:
// --bg-gutter, --bg-surface).
cef_color_t Color(UiView::Background background) {
  NSAppearanceName match =
      [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
  if ([match isEqualToString:NSAppearanceNameDarkAqua]) return CefColorSetARGB(255, 0x16, 0x16, 0x16);
  return background == UiView::Background::kGutter ? CefColorSetARGB(255, 0xf0, 0xf0, 0xf0)
                                                   : CefColorSetARGB(255, 0xf9, 0xf9, 0xf9);
}

}  // namespace

UiView::UiView(std::string page, int height, Background background)
    : url_(std::string(ui_scheme::kOrigin) + page), height_(height), background_(background) {
  router_ = CefMessageRouterBrowserSide::Create(CefMessageRouterConfig());
  router_->AddHandler(this, false);
}

CefRefPtr<CefBrowserView> UiView::view() {
  if (!view_) {
    CefBrowserSettings settings;
    settings.background_color = Color(background_);
    view_ = CefBrowserView::CreateBrowserView(this, url_, settings, nullptr, nullptr, new UiViewDelegate(height_));
  }
  return view_;
}

void UiView::Send(CefRefPtr<CefDictionaryValue> message) {
  if (!listener_) return;
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(message);
  listener_->Success(CefWriteJSON(value, JSON_WRITER_DEFAULT));
}

bool UiView::OnQuery(CefRefPtr<CefBrowser> browser,
                     CefRefPtr<CefFrame> frame,
                     int64_t query_id,
                     const CefString& request,
                     bool persistent,
                     CefRefPtr<Callback> callback) {
  CEF_REQUIRE_UI_THREAD();
  if (!ui_scheme::IsUiUrl(frame->GetURL())) return false;
  CefRefPtr<CefValue> parsed = CefParseJSON(request, JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> message = parsed ? parsed->GetDictionary() : nullptr;
  if (!message) return false;
  const std::string type = message->GetString("type");
  if (type == "listen" && persistent) {
    listener_ = callback;
    listener_id_ = query_id;
    OnConnected();
    return true;
  }
  if (!OnMessage(type, message)) {
    callback->Failure(0, "Unknown message: " + type);
    return true;
  }
  callback->Success("");
  return true;
}

void UiView::OnQueryCanceled(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int64_t query_id) {
  if (query_id == listener_id_) listener_ = nullptr;
}

bool UiView::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                      CefRefPtr<CefFrame> frame,
                                      CefProcessId source_process,
                                      CefRefPtr<CefProcessMessage> message) {
  return router_->OnProcessMessageReceived(browser, frame, source_process, message);
}

void UiView::OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 CefRefPtr<CefContextMenuParams> params,
                                 CefRefPtr<CefMenuModel> model) {
  // Cut, copy and paste in text fields; nothing ("Reload", "Inspect") on the
  // browser's own UI otherwise.
  if (!(params->GetTypeFlags() & CM_TYPEFLAG_EDITABLE)) model->Clear();
}

void UiView::OnDraggableRegionsChanged(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       const std::vector<CefDraggableRegion>& regions) {
  OnDragRegions(regions);
}

void UiView::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  listener_ = nullptr;
  router_->OnBeforeClose(browser);
}

bool UiView::OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                            CefRefPtr<CefFrame> frame,
                            CefRefPtr<CefRequest> request,
                            bool user_gesture,
                            bool is_redirect) {
  router_->OnBeforeBrowse(browser, frame);
  return !ui_scheme::IsUiUrl(request->GetURL());
}

void UiView::OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                       TerminationStatus status,
                                       int error_code,
                                       const CefString& error_string) {
  router_->OnRenderProcessTerminated(browser);
  listener_ = nullptr;
}
