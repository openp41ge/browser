// Copyright (c) 2026 Richard Kielty. MIT License.
// Close handling follows CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#include "spike_client.h"

#include <algorithm>
#include <cstdio>

#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "popout_script.h"

namespace {

constexpr char kPopoutPrefix[] = "openp41ge-popout:";
constexpr char kNewPageName[] = "openp41ge-newpage";
constexpr CGFloat kBannerHeight = 40;

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

// "This page has a player. [Play in pop-out] [Dismiss]" across the top of
// the main window.
@interface SpikeBanner : NSView
- (instancetype)initWithClient:(SpikeClient*)client;
@end

@implementation SpikeBanner {
  SpikeClient* client_;
}

- (instancetype)initWithClient:(SpikeClient*)client {
  if ((self = [super initWithFrame:NSMakeRect(0, 0, 600, kBannerHeight)])) {
    client_ = client;
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithWhite:0.15 alpha:0.95].CGColor;
    self.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    NSTextField* label =
        [NSTextField labelWithString:@"Something is playing in the pop-out. Play this page's video there instead?"];
    label.textColor = NSColor.whiteColor;
    NSButton* play = [NSButton buttonWithTitle:@"Play in pop-out" target:self action:@selector(play:)];
    play.keyEquivalent = @"\r";
    NSButton* dismiss = [NSButton buttonWithTitle:@"Dismiss" target:self action:@selector(dismiss:)];

    NSStackView* stack = [NSStackView stackViewWithViews:@[ label, play, dismiss ]];
    stack.spacing = 12;
    stack.edgeInsets = NSEdgeInsetsMake(0, 16, 0, 16);
    stack.frame = self.bounds;
    stack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:stack];
  }
  return self;
}

- (void)play:(id)sender {
  client_->PlayCurrentPageInPopout();
}

- (void)dismiss:(id)sender {
  client_->DismissBanner();
}

@end

SpikeClient::SpikeClient(NSWindow* main_window, NSView* main_view, std::string selector)
    : main_window_(main_window),
      main_view_(main_view),
      selector_(std::move(selector)),
      window_delegate_([[SpikeWindowDelegate alloc] initWithClient:this]),
      banner_([[SpikeBanner alloc] initWithClient:this]) {
  main_window_.delegate = window_delegate_;
}

// --- Pages ------------------------------------------------------------------

void SpikeClient::CreatePage(const std::string& url) {
  CefWindowInfo window_info;
  const NSSize size = main_view_.bounds.size;
  window_info.SetAsChild(CAST_NSVIEW_TO_CEF_WINDOW_HANDLE(main_view_),
                         CefRect(0, 0, static_cast<int>(size.width), static_cast<int>(size.height)));
  window_info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;
  CefBrowserSettings settings;
  CefBrowserHost::CreateBrowser(window_info, this, url, settings, nullptr, nullptr);
}

NSView* SpikeClient::ViewFor(CefRefPtr<CefBrowser> browser) const {
  return CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
}

void SpikeClient::ShowPage(CefRefPtr<CefBrowser> page) {
  current_page_ = page;
  for (const auto& p : pages_) {
    ViewFor(p).hidden = !p->IsSame(page);
  }
  DismissBanner();
  if (page) {
    main_window_.title = @(page->GetMainFrame()->GetURL().ToString().c_str());
  }
}

void SpikeClient::ClosePage(CefRefPtr<CefBrowser> page) {
  page->GetHost()->CloseBrowser(false);
}

// --- Pop-out ----------------------------------------------------------------

std::string SpikeClient::SelectorJson() const {
  CefRefPtr<CefValue> selector = CefValue::Create();
  selector->SetString(selector_);
  return CefWriteJSON(selector, JSON_WRITER_DEFAULT).ToString();
}

void SpikeClient::RunPopoutScript(CefRefPtr<CefBrowser> page) {
  std::string script = kPopoutScript;
  const std::string placeholder = "%SELECTOR%";
  script.replace(script.find(placeholder), placeholder.size(), SelectorJson());
  // As a user gesture, so the popup blocker allows the child window without
  // disabling popup blocking for websites.
  Evaluate(page, script, /*user_gesture=*/true, nullptr);
}

void SpikeClient::TogglePopout() {
  if (popout_browser_) {
    popout_browser_->GetHost()->CloseBrowser(false);
  } else if (current_page_) {
    RunPopoutScript(current_page_);
  }
}

void SpikeClient::PlayCurrentPageInPopout() {
  DismissBanner();
  if (!current_page_) return;
  if (!popout_browser_) {
    RunPopoutScript(current_page_);
    return;
  }
  // Close the current pop-out (its element returns to its own page), then
  // pop out this page's element in the same place: see OnBeforeClose.
  swap_pending_ = true;
  swap_content_rect_ = [popout_window_ contentRectForFrameRect:popout_window_.frame];
  popout_browser_->GetHost()->CloseBrowser(false);
}

void SpikeClient::DismissBanner() {
  [banner_ removeFromSuperview];
}

void SpikeClient::OfferIfPageHasPlayer(CefRefPtr<CefBrowser> page, int attempts_left) {
  if (!popout_browser_ || !current_page_ || !page->IsSame(current_page_) ||
      (popout_source_ && page->IsSame(popout_source_))) {
    return;
  }
  CefRefPtr<SpikeClient> self(this);
  Evaluate(page, "!!document.querySelector(" + SelectorJson() + ")", false,
           [self, page, attempts_left](bool found) {
             if (found) {
               // On top of the page views, which CEF adds as later subviews.
               self->banner_.frame = NSMakeRect(0, self->main_view_.bounds.size.height - kBannerHeight,
                                                self->main_view_.bounds.size.width, kBannerHeight);
               [self->main_view_ addSubview:self->banner_ positioned:NSWindowAbove relativeTo:nil];
             } else if (attempts_left > 1) {
               // Players often appear after the page has loaded.
               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                 self->OfferIfPageHasPlayer(page, attempts_left - 1);
               });
             }
           });
}

// --- DevTools evaluation ----------------------------------------------------

void SpikeClient::Evaluate(CefRefPtr<CefBrowser> page,
                           const std::string& expression,
                           bool user_gesture,
                           std::function<void(bool)> callback) {
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("expression", expression);
  params->SetBool("returnByValue", true);
  if (user_gesture) params->SetBool("userGesture", true);
  const int id = page->GetHost()->ExecuteDevToolsMethod(0, "Runtime.evaluate", params);
  if (id && callback) {
    pending_results_[{page->GetIdentifier(), id}] = std::move(callback);
  }
}

void SpikeClient::OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser,
                                         int message_id,
                                         bool success,
                                         const void* result,
                                         size_t result_size) {
  auto it = pending_results_.find({browser->GetIdentifier(), message_id});
  if (it == pending_results_.end()) return;
  std::function<void(bool)> callback = std::move(it->second);
  pending_results_.erase(it);

  bool value = false;
  if (success) {
    // {"result": {"type": "boolean", "value": true}}
    CefRefPtr<CefValue> parsed = CefParseJSON(result, result_size, JSON_PARSER_RFC);
    CefRefPtr<CefDictionaryValue> outer = parsed ? parsed->GetDictionary() : nullptr;
    CefRefPtr<CefDictionaryValue> inner = outer ? outer->GetDictionary("result") : nullptr;
    value = inner && inner->GetType("value") == VTYPE_BOOL && inner->GetBool("value");
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    callback(value);
  });
}

// --- Life span --------------------------------------------------------------

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
    // Links while popped out ("openp41ge-newpage"), and any other new
    // window: open as a page in the main window (no real tabs in the spike).
    if (name != kNewPageName && target_url.empty()) return true;
    CreatePage(target_url);
    return true;
  }
  if (popout_window_) return true;  // One pop-out at a time.

  double x = 0, y = 0, width = 0, height = 0;
  if (std::sscanf(name.c_str() + sizeof(kPopoutPrefix) - 1, "%lf,%lf,%lf,%lf", &x, &y, &width,
                  &height) != 4 ||
      width <= 0 || height <= 0) {
    return true;
  }

  NSRect content_rect;
  if (swap_pending_) {
    // Same place and width as the pop-out it replaces; height from the new
    // element's shape.
    const CGFloat new_height = swap_content_rect_.size.width * height / width;
    content_rect = NSMakeRect(swap_content_rect_.origin.x, NSMaxY(swap_content_rect_) - new_height,
                              swap_content_rect_.size.width, new_height);
    swap_pending_ = false;
  } else {
    // Right over the element: its viewport rect (top-left origin) -> screen.
    NSView* page_view = ViewFor(browser);
    NSRect in_view = NSMakeRect(x, y, width, height);
    if (!page_view.isFlipped) {
      in_view.origin.y = page_view.bounds.size.height - y - height;
    }
    content_rect = [main_window_ convertRectToScreen:[page_view convertRect:in_view toView:nil]];
  }

  NSWindow* window = [[NSWindow alloc]
      initWithContentRect:content_rect
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
  popout_source_ = browser;

  window_info.SetAsChild(CAST_NSVIEW_TO_CEF_WINDOW_HANDLE(window.contentView),
                         CefRect(0, 0, static_cast<int>(content_rect.size.width),
                                 static_cast<int>(content_rect.size.height)));
  window_info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;
  client = this;

  [window makeKeyAndOrderFront:nil];
  return false;  // Let CEF create the child window's browser in our window.
}

void SpikeClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  // Make the browser view follow its window's size.
  NSView* view = ViewFor(browser);
  view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  view.frame = view.superview.bounds;

  if (browser->IsPopup()) {
    popout_browser_ = browser;
    return;
  }
  devtools_registrations_[browser->GetIdentifier()] =
      browser->GetHost()->AddDevToolsMessageObserver(this);
  pages_.push_back(browser);
  ShowPage(browser);
}

bool SpikeClient::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_closing_ = true;
    return false;  // CEF closes the window; WindowShouldClose now allows it.
  }
  // Pages share the main window, so don't close it: destroy just this view.
  [ViewFor(browser) removeFromSuperview];
  return true;
}

void SpikeClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_browser_ = nullptr;
    popout_window_ = nil;
    popout_closing_ = false;
    // The element is back in its page. If that page was only kept alive in
    // the background for the pop-out, close it too.
    CefRefPtr<CefBrowser> source = popout_source_;
    popout_source_ = nullptr;
    if (source && current_page_ && !source->IsSame(current_page_) && !quitting_) {
      ClosePage(source);
    }
    if (swap_pending_ && current_page_) {
      RunPopoutScript(current_page_);
    }
  } else {
    devtools_registrations_.erase(browser->GetIdentifier());
    pages_.erase(std::remove_if(pages_.begin(), pages_.end(),
                                [&](const CefRefPtr<CefBrowser>& p) { return p->IsSame(browser); }),
                 pages_.end());
    if (current_page_ && current_page_->IsSame(browser)) {
      ShowPage(pages_.empty() ? nullptr : pages_.back());
    }
  }
  if (pages_.empty() && !popout_browser_) {
    CefQuitMessageLoop();
  }
}

void SpikeClient::CloseAll() {
  quitting_ = true;
  if (popout_browser_) popout_browser_->GetHost()->CloseBrowser(false);
  for (const auto& page : std::vector<CefRefPtr<CefBrowser>>(pages_)) {
    ClosePage(page);
  }
  if (pages_.empty() && !popout_browser_) CefQuitMessageLoop();
}

bool SpikeClient::WindowShouldClose(NSWindow* window) {
  if (window == popout_window_) {
    if (!popout_browser_ || popout_closing_) return true;  // DoClose already ran.
    popout_browser_->GetHost()->CloseBrowser(false);
    return false;
  }
  // The main window: close every browser; the app quits when they're gone.
  CloseAll();
  return false;
}

// --- Display / load ---------------------------------------------------------

void SpikeClient::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  if (current_page_ && browser->IsSame(current_page_)) {
    main_window_.title = @(title.ToString().c_str());
  }
}

void SpikeClient::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                       bool is_loading,
                                       bool can_go_back,
                                       bool can_go_forward) {
  if (!is_loading && !browser->IsPopup()) {
    OfferIfPageHasPlayer(browser, 5);
  }
}
