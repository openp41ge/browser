// Copyright (c) 2026 Richard Kielty. MIT License.
// Close handling follows CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#include "spike_client.h"

#include <cstdio>

#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "popout_script.h"

namespace {

constexpr char kPopoutPrefix[] = "openp41ge-popout:";

}  // namespace

// Routes a window's close button through the browser, so the page can run
// its unload handlers (and move the element back) before the window goes.
@interface SpikeWindowDelegate : NSObject <NSWindowDelegate>
- (instancetype)initWithClient:(SpikeClient*)client;
@end

@implementation SpikeWindowDelegate {
  SpikeClient* client_;  // Outlives the windows.
}

- (instancetype)initWithClient:(SpikeClient*)client {
  if ((self = [super init])) {
    client_ = client;
  }
  return self;
}

- (BOOL)windowShouldClose:(NSWindow*)window {
  return client_->WindowShouldClose(window);
}

// CEF finishes closing a browser only once its view is destroyed, so drop
// the window's content (and with it the browser view) as the window closes.
- (void)windowWillClose:(NSNotification*)notification {
  NSWindow* window = notification.object;
  window.contentView = nil;
}

@end

SpikeClient::SpikeClient(NSWindow* main_window, NSView* main_view, std::string selector)
    : main_window_(main_window),
      main_view_(main_view),
      selector_(std::move(selector)),
      window_delegate_([[SpikeWindowDelegate alloc] initWithClient:this]) {
  main_window_.delegate = window_delegate_;
}

void SpikeClient::TogglePopout() {
  if (!main_browser_) return;
  CefRefPtr<CefValue> selector = CefValue::Create();
  selector->SetString(selector_);
  std::string script = kPopoutScript;
  const std::string placeholder = "%SELECTOR%";
  script.replace(script.find(placeholder), placeholder.size(),
                 CefWriteJSON(selector, JSON_WRITER_DEFAULT).ToString());
  // Run it as if from a user gesture so the popup blocker allows the child
  // window, without disabling popup blocking for websites.
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("expression", script);
  params->SetBool("userGesture", true);
  main_browser_->GetHost()->ExecuteDevToolsMethod(0, "Runtime.evaluate", params);
}

void SpikeClient::CloseAll() {
  quitting_ = true;
  if (popout_browser_) popout_browser_->GetHost()->CloseBrowser(false);
  if (main_browser_) main_browser_->GetHost()->CloseBrowser(false);
  if (!main_browser_ && !popout_browser_) CefQuitMessageLoop();
}

bool SpikeClient::WindowShouldClose(NSWindow* window) {
  const bool is_popout = window == popout_window_;
  CefRefPtr<CefBrowser> browser = is_popout ? popout_browser_ : main_browser_;
  const bool closing = is_popout ? popout_closing_ : main_closing_;
  if (!browser || closing) {
    return true;  // DoClose already ran: let the window go.
  }
  if (is_popout) {
    browser->GetHost()->CloseBrowser(false);
  } else {
    CloseAll();
  }
  return false;
}

bool SpikeClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
                                bool* no_javascript_access) {
  CEF_REQUIRE_UI_THREAD();
  const std::string name = target_frame_name;
  if (name.rfind(kPopoutPrefix, 0) != 0) {
    // Not a pop-out. No tabs in the spike, so load it in the page instead.
    browser->GetMainFrame()->LoadURL(target_url);
    return true;
  }
  if (popout_window_) return true;  // One pop-out at a time.

  double x = 0, y = 0, width = 0, height = 0;
  if (std::sscanf(name.c_str() + sizeof(kPopoutPrefix) - 1, "%lf,%lf,%lf,%lf", &x, &y, &width,
                  &height) != 4 ||
      width <= 0 || height <= 0) {
    return true;
  }

  // The element's viewport rect (top-left origin) -> screen coordinates.
  NSRect in_view = NSMakeRect(x, y, width, height);
  if (!main_view_.isFlipped) {
    in_view.origin.y = main_view_.bounds.size.height - y - height;
  }
  const NSRect on_screen =
      [main_window_ convertRectToScreen:[main_view_ convertRect:in_view toView:nil]];

  NSWindow* window = [[NSWindow alloc]
      initWithContentRect:on_screen
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  window.releasedWhenClosed = NO;
  window.title = @"Pop-out";
  window.level = NSFloatingWindowLevel;
  window.collectionBehavior =
      NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
  window.contentAspectRatio = NSMakeSize(width, height);
  window.delegate = window_delegate_;
  popout_window_ = window;

  window_info.SetAsChild(CAST_NSVIEW_TO_CEF_WINDOW_HANDLE(window.contentView),
                         CefRect(0, 0, static_cast<int>(width), static_cast<int>(height)));
  window_info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;
  client = this;

  [window makeKeyAndOrderFront:nil];
  return false;  // Let CEF create the child window's browser in our window.
}

void SpikeClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_browser_ = browser;
  } else {
    main_browser_ = browser;
  }
  // Make the browser view follow its window's size.
  NSView* view = CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
  view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  view.frame = view.superview.bounds;
}

bool SpikeClient::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_closing_ = true;
  } else {
    main_closing_ = true;
  }
  return false;  // CEF closes the window; WindowShouldClose now allows it.
}

void SpikeClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_browser_ = nullptr;
    popout_window_ = nil;
    popout_closing_ = false;
  } else {
    main_browser_ = nullptr;
  }
  if (!main_browser_ && !popout_browser_ && (quitting_ || main_closing_)) {
    CefQuitMessageLoop();
  }
}

void SpikeClient::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  if (!browser->IsPopup()) {
    main_window_.title = @(title.ToString().c_str());
  }
}
