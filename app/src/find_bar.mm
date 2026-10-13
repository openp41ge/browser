// Copyright (c) 2026 Richard Kielty. MIT License.

#include "find_bar.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include "include/wrapper/cef_helpers.h"

// Borderless, and still able to take the keyboard (for the field).
@interface FindBarWindow : NSWindow
@end

@implementation FindBarWindow
- (BOOL)canBecomeKeyWindow {
  return YES;
}
@end

namespace {

// The browser window's corner radius (macOS draws its windows' corners), so
// the row's bottom corners, on the window's, follow them.
CGFloat WindowCornerRadius() {
  if (@available(macOS 26, *)) return 12;
  return 10;
}

// CEF screen coordinates (origin at the main screen's top left) as a Cocoa
// frame (origin at its bottom left).
NSRect ToFrame(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}

}  // namespace

struct FindBar::Native {
  FindBarWindow* window = nil;
};

class FindBar::Page : public UiView {
 public:
  explicit Page(FindBar* owner) : UiView("findbar.html", CefSize(1, kHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }
  // Its window, closed once the page has (the page is in it).
  void CloseWithWindow(NSWindow* window) {
    window_ = window;
    if (CefRefPtr<CefBrowser> page = browser()) {
      page->GetHost()->CloseBrowser(true);
    } else {
      [window_ close];
      window_ = nil;
    }
  }

  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
    UiView::OnAfterCreated(browser);
    // The page fills the window, at whatever size it's given.
    NSView* view = (__bridge NSView*)browser->GetHost()->GetWindowHandle();
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  }

  // Its window has no close button for CEF to press (performClose:), so the
  // page closes it itself, and finishes closing as it goes (see DoClose in
  // cef_life_span_handler.h).
  bool DoClose(CefRefPtr<CefBrowser> browser) override {
    // Its view out of the window, which tears the page down; then the window.
    [(__bridge NSView*)browser->GetHost()->GetWindowHandle() removeFromSuperview];
    [window_ close];
    window_ = nil;
    return true;
  }

  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
    UiView::OnBeforeClose(browser);
    [window_ close];
    window_ = nil;
  }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "find") {
      owner_->OnFind(message->GetString("text"), message->GetBool("forward"));
    } else if (type == "close") {
      owner_->OnClose();
    } else {
      return false;
    }
    return true;
  }

 private:
  FindBar* owner_;           // Null once the find bar has gone.
  NSWindow* window_ = nil;   // While closing.

  IMPLEMENT_REFCOUNTING(Page);
};

FindBar::FindBar(CefRefPtr<CefWindow> parent, Callbacks callbacks)
    : parent_(parent), callbacks_(std::move(callbacks)), page_(new Page(this)), native_(new Native()) {}

FindBar::~FindBar() {
  page_->Detach();
}

void FindBar::Open(const CefRect& bounds, const std::string& text) {
  CEF_REQUIRE_UI_THREAD();
  text_ = text;
  wanted_ = true;
  if (!native_->window) {
    FindBarWindow* window = [[FindBarWindow alloc] initWithContentRect:ToFrame(bounds)
                                                             styleMask:NSWindowStyleMaskBorderless
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO];
    window.releasedWhenClosed = NO;
    window.hasShadow = NO;
    // Square at the top; at the bottom, rounded as the browser window is.
    window.opaque = NO;
    window.backgroundColor = NSColor.clearColor;
    NSView* content = window.contentView;
    content.wantsLayer = YES;
    content.layer.cornerRadius = WindowCornerRadius();
    content.layer.cornerCurve = kCACornerCurveContinuous;
    content.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;  // The bottom ones.
    content.layer.masksToBounds = YES;
    native_->window = window;
    Present();
    page_->CreateIn((__bridge CefWindowHandle)window.contentView, CefRect(0, 0, bounds.width, bounds.height));
    return;  // The page gets the keyboard and its text once it's ready (OnConnected).
  }
  [native_->window setFrame:ToFrame(bounds) display:YES];
  Present();
  SendOpen();
}

void FindBar::Present() {
  FindBarWindow* window = native_->window;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  if (window.parentWindow != parent) [parent addChildWindow:window ordered:NSWindowAbove];
  [window makeKeyAndOrderFront:nil];
  if (CefRefPtr<CefBrowser> page = page_->browser()) {
    ((__bridge NSView*)page->GetHost()->GetWindowHandle()).hidden = NO;
    page->GetHost()->SetFocus(true);
  }
}

void FindBar::MoveTo(const CefRect& bounds) {
  if (native_->window && wanted_) [native_->window setFrame:ToFrame(bounds) display:YES];
}

void FindBar::ShowResult(int count, int active) {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "result");
  message->SetInt("count", count);
  message->SetInt("active", active);
  page_->Send(message);
}

void FindBar::Hide() {
  wanted_ = false;
  if (FindBarWindow* window = native_->window) {
    [window.parentWindow removeChildWindow:window];
    [window orderOut:nil];
  }
  // Hidden as far as the page is concerned too (it doesn't follow a window
  // of our own).
  if (CefRefPtr<CefBrowser> page = page_->browser()) {
    ((__bridge NSView*)page->GetHost()->GetWindowHandle()).hidden = YES;
  }
}

void FindBar::Close() {
  Hide();
  callbacks_ = {};
  if (FindBarWindow* window = native_->window) {
    native_->window = nil;
    page_->CloseWithWindow(window);
  }
}

void FindBar::OnConnected() {
  if (!wanted_) return;
  // The keyboard, again now its page is ready: opened from a menu, the
  // browser window takes it back as the menu closes.
  Present();
  SendOpen();
}

void FindBar::SendOpen() {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "open");
  message->SetString("text", text_);
  page_->Send(message);
}

void FindBar::OnFind(const std::string& text, bool forward) {
  text_ = text;
  if (wanted_ && callbacks_.find) callbacks_.find(text, forward);
}

void FindBar::OnClose() {
  if (wanted_ && callbacks_.close) callbacks_.close();
}
