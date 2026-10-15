// Copyright (c) 2026 Richard Kielty. MIT License.

#include "suggestions_popup.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>

#include "include/wrapper/cef_helpers.h"

namespace {

// A height to start at, before the page reports its own.
constexpr int kInitialHeight = 40;
// The bottom corners' radius, as the tab preview's.
constexpr CGFloat kRadius = 8;
// Room left between it and the window's bottom.
constexpr int kBottomMargin = 8;

// CEF screen coordinates (origin at the main screen's top left) as a Cocoa
// frame (origin at its bottom left), and back.
NSRect ToFrame(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}
CefRect FromFrame(NSRect f) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return CefRect(static_cast<int>(f.origin.x), static_cast<int>(screen_height - f.origin.y - f.size.height),
                 static_cast<int>(f.size.width), static_cast<int>(f.size.height));
}

}  // namespace

struct SuggestionsPopup::Native {
  NSPanel* panel = nil;
};

class SuggestionsPopup::Page : public UiView {
 public:
  explicit Page(SuggestionsPopup* owner)
      : UiView("suggestions.html", CefSize(1, kInitialHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "size") {
      owner_->OnSize(message->GetInt("height"));
    } else if (type == "pick") {
      owner_->OnPick(message->GetInt("index"));
    } else if (type == "remove") {
      owner_->OnRemove(message->GetInt("index"));
    } else {
      return false;
    }
    return true;
  }

 private:
  SuggestionsPopup* owner_;  // Null once the popup has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

SuggestionsPopup::SuggestionsPopup(CefRefPtr<CefWindow> parent, PickCallback pick, PickCallback remove)
    : parent_(parent),
      pick_(std::move(pick)),
      remove_(std::move(remove)),
      page_(new Page(this)),
      native_(new Native()) {}

SuggestionsPopup::~SuggestionsPopup() {
  page_->Detach();
}

void SuggestionsPopup::Show(CefRefPtr<CefListValue> rows, int selected, const CefRect& anchor, int width) {
  CEF_REQUIRE_UI_THREAD();
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  if (!parent) return;
  // A copy: `rows` belongs to the tab bar's message, gone once it's handled.
  rows_ = rows->Copy();
  selected_ = selected;
  wanted_ = true;
  // Centred on the tab, within the window; its corners square where it
  // meets the window's sides.
  const CefRect window = FromFrame(parent.frame);
  width = std::min(width, window.width);
  const int x = std::clamp(anchor.x + anchor.width / 2 - width / 2, window.x, window.x + window.width - width);
  square_left_ = x <= window.x;
  square_right_ = x + width >= window.x + window.width;
  const int top = anchor.y + anchor.height;
  max_height_ = std::max(kInitialHeight, window.y + window.height - top - kBottomMargin);
  bounds_ = CefRect(x, top, width, bounds_.height > 0 ? std::min(bounds_.height, max_height_) : kInitialHeight);

  if (!native_->panel) {
    // Never the key window (the keyboard stays in the tab's address); a
    // menu's level, as web views only follow the pointer (hover) in an
    // inactive window above the normal level.
    NSPanel* panel = [[NSPanel alloc] initWithContentRect:ToFrame(bounds_)
                                                styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    panel.releasedWhenClosed = NO;
    panel.level = NSPopUpMenuWindowLevel;
    panel.opaque = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = YES;
    NSView* content = panel.contentView;
    content.wantsLayer = YES;
    content.layer.cornerRadius = kRadius;
    content.layer.cornerCurve = kCACornerCurveContinuous;
    content.layer.masksToBounds = YES;
    native_->panel = panel;
    Place();
    // Shown once its page has laid the rows out (OnSize).
    page_->CreateIn((__bridge CefWindowHandle)content, CefRect(0, 0, bounds_.width, bounds_.height));
    return;
  }
  Place();
  SetPageHidden(false);
  SendRows();
}

// Hidden as far as the page is concerned too (it doesn't follow a window of
// our own).
void SuggestionsPopup::SetPageHidden(bool hidden) {
  if (CefRefPtr<CefBrowser> page = page_->browser()) {
    ((__bridge NSView*)page->GetHost()->GetWindowHandle()).hidden = hidden;
  }
}

void SuggestionsPopup::Place() {
  NSPanel* panel = native_->panel;
  if (!panel) return;
  [panel setFrame:ToFrame(bounds_) display:YES];
  CACornerMask corners = 0;
  if (!square_left_) corners |= kCALayerMinXMinYCorner;
  if (!square_right_) corners |= kCALayerMaxXMinYCorner;
  panel.contentView.layer.maskedCorners = corners;
  [panel invalidateShadow];
}

void SuggestionsPopup::Hide() {
  wanted_ = false;
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
  SetPageHidden(true);
}

void SuggestionsPopup::Close() {
  Hide();
  pick_ = nullptr;
  remove_ = nullptr;
  if (native_->panel) {
    native_->panel = nil;
    page_->CloseInWindow();  // Its panel with it.
  }
}

void SuggestionsPopup::OnConnected() {
  SendRows();
}

void SuggestionsPopup::SendRows() {
  if (!rows_) return;
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "rows");
  message->SetList("rows", rows_->Copy());
  message->SetInt("selected", selected_);
  message->SetInt("maxHeight", max_height_);
  message->SetBool("squareLeft", square_left_);
  message->SetBool("squareRight", square_right_);
  page_->Send(message);
}

void SuggestionsPopup::OnSize(int height) {
  NSPanel* panel = native_->panel;
  if (!panel || height <= 0) return;
  bounds_.height = std::min(height, max_height_);
  if (!wanted_) return;
  Place();
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  if (panel.parentWindow != parent) [parent addChildWindow:panel ordered:NSWindowAbove];
  if (!panel.visible) [panel orderFront:nil];
}

void SuggestionsPopup::OnPick(int index) {
  if (wanted_ && pick_) pick_(index);
}

void SuggestionsPopup::OnRemove(int index) {
  if (wanted_ && remove_) remove_(index);
}
