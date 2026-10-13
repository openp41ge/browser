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

// The outline macOS draws along a window's edges, inside its dark edge: a
// light hairline a point wide (most visible in dark mode).
CGFloat WindowOutline(NSWindow* window) {
  return 1;
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
  FindBar* owner_;  // Null once the find bar has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

FindBar::FindBar(CefRefPtr<CefWindow> parent, Callbacks callbacks)
    : parent_(parent), callbacks_(std::move(callbacks)), page_(new Page(this)), native_(new Native()) {}

FindBar::~FindBar() {
  page_->Detach();
}

void FindBar::Open(const Placement& placement, const std::string& text) {
  CEF_REQUIRE_UI_THREAD();
  text_ = text;
  wanted_ = true;
  if (!native_->window) {
    FindBarWindow* window = [[FindBarWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                                             styleMask:NSWindowStyleMaskBorderless
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO];
    window.releasedWhenClosed = NO;
    window.hasShadow = NO;
    // Square, but for any of the window's corners it's on (Place).
    window.opaque = NO;
    window.backgroundColor = NSColor.clearColor;
    NSView* content = window.contentView;
    content.wantsLayer = YES;
    content.layer.cornerCurve = kCACornerCurveContinuous;
    content.layer.masksToBounds = YES;
    native_->window = window;
    Place(placement);
    Present();
    const NSSize size = content.bounds.size;
    page_->CreateIn((__bridge CefWindowHandle)content, CefRect(0, 0, size.width, size.height));
    return;  // The page gets the keyboard and its text once it's ready (OnConnected).
  }
  Place(placement);
  Present();
  SendOpen();
}

void FindBar::Place(const Placement& placement) {
  FindBarWindow* window = native_->window;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  const CGFloat outline = WindowOutline(parent);
  NSRect frame = ToFrame(placement.bounds);
  if (placement.left) {
    frame.origin.x += outline;
    frame.size.width -= outline;
  }
  if (placement.right) frame.size.width -= outline;
  if (placement.bottom) frame.origin.y += outline;
  [window setFrame:frame display:YES];
  // Its bottom corners rounded where they're the window's.
  CACornerMask corners = 0;
  if (placement.bottom && placement.left) corners |= kCALayerMinXMinYCorner;
  if (placement.bottom && placement.right) corners |= kCALayerMaxXMinYCorner;
  window.contentView.layer.maskedCorners = corners;
  window.contentView.layer.cornerRadius = WindowCornerRadius() - outline;
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

void FindBar::MoveTo(const Placement& placement) {
  if (native_->window && wanted_) Place(placement);
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
  if (native_->window) {
    native_->window = nil;
    page_->CloseInWindow();  // Its window with it.
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
