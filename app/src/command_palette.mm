// Copyright (c) 2026 Richard Kielty. MIT License.

#include "command_palette.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <functional>

#include "browser_window.h"

namespace {

constexpr CGFloat kCornerRadius = 8;

// openp41ge's --border-color.
NSColor* BorderColor() {
  const bool dark = [[NSApp.effectiveAppearance
      bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]]
      isEqualToString:NSAppearanceNameDarkAqua];
  const CGFloat grey = (dark ? 0x33 : 0xd4) / 255.0;
  return [NSColor colorWithSRGBRed:grey green:grey blue:grey alpha:1];
}

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}

}  // namespace

// The palette's panel: borderless and rounded, with a 1px border on top of
// everything (openp41ge separates panels with borders, not shadows). It
// takes the keyboard, and reports losing it.
@interface PalettePanel : NSPanel
@property(nonatomic, copy) void (^onResignKey)(void);
@property(nonatomic, readonly) NSView* host;  // The page goes in here.
@end

@implementation PalettePanel {
  CAShapeLayer* _border;
}

- (instancetype)initWithSize:(NSSize)size {
  self = [super initWithContentRect:NSMakeRect(0, 0, size.width, size.height)
                          styleMask:NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:NO];
  if (!self) return nil;
  self.releasedWhenClosed = NO;
  self.opaque = NO;
  self.backgroundColor = NSColor.clearColor;
  self.hasShadow = NO;

  NSView* content = self.contentView;
  content.wantsLayer = YES;
  content.layer.cornerRadius = kCornerRadius;
  content.layer.cornerCurve = kCACornerCurveCircular;  // Matches the border's path.
  content.layer.masksToBounds = YES;

  _host = [[NSView alloc] initWithFrame:content.bounds];
  _host.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [content addSubview:_host];

  // The border is a layer of its own on top, so the page's drawing can't
  // cover any of it; its line runs half a point inside the edge.
  _border = [CAShapeLayer layer];
  _border.zPosition = 1000;
  _border.fillColor = nil;
  _border.lineWidth = 1;
  _border.frame = content.layer.bounds;
  CGPathRef path = CGPathCreateWithRoundedRect(CGRectInset(content.layer.bounds, 0.5, 0.5), kCornerRadius - 0.5,
                                               kCornerRadius - 0.5, nullptr);
  _border.path = path;
  CGPathRelease(path);
  [content.layer addSublayer:_border];
  [self updateColors];
  return self;
}

- (void)updateColors {
  _border.strokeColor = BorderColor().CGColor;
}

- (BOOL)canBecomeKeyWindow {
  return YES;
}

- (void)resignKeyWindow {
  [super resignKeyWindow];
  if (self.onResignKey) self.onResignKey();
}

// Closing tears down the page's view, which lets CEF finish closing it.
- (void)close {
  [super close];
  self.contentView = nil;
}

@end

struct CommandPalette::Native {
  PalettePanel* panel = nil;
};

CommandPalette::CommandPalette(BrowserWindow* owner)
    : UiView("palette.html", 0, Background::kSurface), owner_(owner), native_(new Native()) {}

CommandPalette::~CommandPalette() = default;

void CommandPalette::Show(bool new_tab) {
  if (!owner_ || !owner_->window()) return;
  new_tab_ = new_tab;
  shown_ = true;

  NSWindow* parent = ((__bridge NSView*)owner_->window()->GetWindowHandle()).window;
  if (!native_->panel) {
    PalettePanel* panel = [[PalettePanel alloc] initWithSize:NSMakeSize(kWidth, kHeight)];
    CefRefPtr<CommandPalette> self(this);
    panel.onResignKey = ^{
      // Like a menu: clicking anywhere else dismisses it.
      if (self->shown_) self->Hide();
    };
    native_->panel = panel;
    CefWindowInfo window_info;
    window_info.SetAsChild((__bridge CefWindowHandle)panel.host, CefRect(0, 0, kWidth, kHeight));
    CreateBrowser(window_info);
  }
  PalettePanel* panel = native_->panel;

  // Centred near the top of the browser window, below its top bar.
  const CefRect w = owner_->window()->GetBounds();
  [panel setFrame:ToCocoa(CefRect(w.x + (w.width - kWidth) / 2, w.y + TopBar::kHeight + 12, kWidth, kHeight))
          display:NO];
  [panel updateColors];  // In case the light/dark setting changed.
  if (panel.parentWindow != parent) [parent addChildWindow:panel ordered:NSWindowAbove];
  [panel makeKeyAndOrderFront:nil];
  if (CefRefPtr<CefBrowser> page = browser()) page->GetHost()->SetFocus(true);
  SendOpen();
}

void CommandPalette::Hide() {
  shown_ = false;
  if (PalettePanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
}

void CommandPalette::Detach() {
  owner_ = nullptr;
  shown_ = false;
  if (PalettePanel* panel = native_->panel) {
    native_->panel = nil;
    panel.onResignKey = nil;
    if (CefRefPtr<CefBrowser> page = browser()) page->GetHost()->CloseBrowser(true);
    [panel.parentWindow removeChildWindow:panel];
    [panel close];
  }
}

void CommandPalette::OnConnected() {
  if (shown_) SendOpen();
}

void CommandPalette::SendOpen() {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "open");
  message->SetBool("newTab", new_tab_);
  CefRefPtr<Tab> tab = owner_ && !new_tab_ ? owner_->active_tab() : nullptr;
  message->SetString("text", tab && tab->url != "about:blank" ? tab->url : "");
  Send(message);
}

bool CommandPalette::OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) {
  if (type == "go") {
    Hide();
    if (!owner_) return true;
    const std::string url = message->GetString("url");
    if (new_tab_) {
      owner_->OpenTab(url);
    } else if (CefRefPtr<CefBrowser> page = owner_->active_browser()) {
      page->GetMainFrame()->LoadURL(url);
    }
    if (owner_->window()) owner_->window()->Activate();
    if (CefRefPtr<Tab> tab = owner_->active_tab()) tab->view()->RequestFocus();
  } else if (type == "dismiss") {
    Hide();
    if (owner_ && owner_->window()) owner_->window()->Activate();
  } else {
    return false;
  }
  return true;
}
