// Copyright (c) 2026 Richard Kielty. MIT License.

#include <set>

#include "ui/ui_view.h"

#import <Cocoa/Cocoa.h>

#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "ui/ui_scheme.h"

namespace {

// Alloy style, at the UI's preferred size.
class UiViewDelegate : public CefBrowserViewDelegate {
 public:
  explicit UiViewDelegate(CefSize size) : size_(size) {}
  cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefSize GetPreferredSize(CefRefPtr<CefView> view) override { return size_; }

 private:
  CefSize size_;
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

// Every UI view, for ReloadAll.
std::set<UiView*>& LiveViews() {
  static std::set<UiView*> views;
  return views;
}

UiView::UiView(std::string page, CefSize preferred_size, Background background)
    : url_(std::string(ui_scheme::kOrigin) + page), preferred_size_(preferred_size), background_(background) {
  router_ = CefMessageRouterBrowserSide::Create(CefMessageRouterConfig());
  router_->AddHandler(this, false);
  LiveViews().insert(this);
}

UiView::~UiView() {
  LiveViews().erase(this);
}

void UiView::ReloadAll() {
  for (UiView* view : LiveViews()) {
    if (view->browser_) view->browser_->ReloadIgnoreCache();
  }
}

CefRefPtr<CefBrowserView> UiView::view() {
  if (!view_) {
    CefBrowserSettings settings;
    settings.background_color = Color(background_);
    view_ = CefBrowserView::CreateBrowserView(this, url_, settings, nullptr, nullptr, new UiViewDelegate(preferred_size_));
  }
  return view_;
}

namespace {

// Pages made with CreateIn not yet closed, and what's waiting for them.
int g_own_window_pages = 0;
std::function<void()> g_when_closed;

}  // namespace

void UiView::WhenOwnWindowPagesClosed(std::function<void()> done) {
  if (g_own_window_pages == 0) {
    done();
    return;
  }
  g_when_closed = std::move(done);
}

void UiView::CreateIn(CefWindowHandle parent, const CefRect& bounds) {
  ++g_own_window_pages;
  own_window_ = true;
  host_window_ = CFBridgingRetain(((__bridge NSView*)parent).window);
  CefWindowInfo info;
  info.SetAsChild(parent, bounds);
  info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;
  CefBrowserSettings settings;
  settings.background_color = Color(background_);
  CefBrowserHost::CreateBrowser(info, this, url_, settings, nullptr, nullptr);
}

void UiView::CloseInWindow() {
  if (browser_) {
    browser_->GetHost()->CloseBrowser(true);
  } else {
    close_pending_ = true;  // Once it's made (OnAfterCreated).
  }
}

void UiView::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  browser_ = browser;
  if (!own_window_) return;
  ((__bridge NSView*)browser->GetHost()->GetWindowHandle()).autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  if (close_pending_) browser->GetHost()->CloseBrowser(true);
}

bool UiView::DoClose(CefRefPtr<CefBrowser> browser) {
  if (!own_window_) return false;
  // Its view out of the window, which tears the page down; then the window.
  [(__bridge NSView*)browser->GetHost()->GetWindowHandle() removeFromSuperview];
  if (host_window_) {
    NSWindow* window = CFBridgingRelease(host_window_);
    host_window_ = nullptr;
    [window.parentWindow removeChildWindow:window];
    [window close];
  }
  return true;
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

bool UiView::OnShowPermissionPrompt(CefRefPtr<CefBrowser> browser,
                                    uint64_t prompt_id,
                                    const CefString& requesting_origin,
                                    uint32_t requested_permissions,
                                    CefRefPtr<CefPermissionPromptCallback> callback) {
  constexpr uint32_t kLocalNetwork = CEF_PERMISSION_TYPE_LOCAL_NETWORK | CEF_PERMISSION_TYPE_LOOPBACK_NETWORK;
  const bool allowed =
      ui_scheme::IsUiUrl(browser->GetMainFrame()->GetURL()) && (requested_permissions & ~kLocalNetwork) == 0;
  callback->Continue(allowed ? CEF_PERMISSION_RESULT_ACCEPT : CEF_PERMISSION_RESULT_DENY);
  return true;
}

void UiView::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  listener_ = nullptr;
  browser_ = nullptr;
  router_->OnBeforeClose(browser);
  if (own_window_ && --g_own_window_pages == 0 && g_when_closed) {
    std::function<void()> done = std::move(g_when_closed);
    g_when_closed = nullptr;
    done();
  }
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
