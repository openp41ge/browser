// Copyright (c) 2026 Richard Kielty. MIT License.

#include "drop_preview.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

namespace {

// openp41ge's drop colour: rgb(74, 158, 255).
CGColorRef Blue(CGFloat alpha) {
  return [NSColor colorWithSRGBRed:74 / 255.0 green:158 / 255.0 blue:1 alpha:alpha].CGColor;
}

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}

// Room around the ring for its glow.
constexpr CGFloat kGlow = 10;

}  // namespace

struct DropPreview::Native {
  NSPanel* panel = nil;
  CALayer* box = nil;
};

DropPreview::DropPreview(CefRefPtr<CefWindow> parent) : parent_(parent), native_(new Native()) {}

DropPreview::~DropPreview() {
  if (native_->panel) {
    [native_->panel.parentWindow removeChildWindow:native_->panel];
    [native_->panel close];
  }
}

void DropPreview::Show(const CefRect& screen_rect) {
  if (!native_->panel) {
    NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                                styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    panel.releasedWhenClosed = NO;
    panel.opaque = NO;
    panel.backgroundColor = NSColor.clearColor;
    panel.hasShadow = NO;
    panel.ignoresMouseEvents = YES;
    NSView* content = panel.contentView;
    content.wantsLayer = YES;
    // The ring: 3px, with a glow and a wash (openp41ge's drop-box).
    CALayer* box = [CALayer layer];
    box.borderWidth = 3;
    box.borderColor = Blue(1);
    box.backgroundColor = Blue(0.2);
    box.shadowColor = Blue(1);
    box.shadowOpacity = 0.6;
    box.shadowRadius = 5;
    box.shadowOffset = CGSizeZero;
    [content.layer addSublayer:box];
    native_->panel = panel;
    native_->box = box;
  }
  NSPanel* panel = native_->panel;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  [panel setFrame:NSInsetRect(ToCocoa(screen_rect), -kGlow, -kGlow) display:NO];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  native_->box.frame = NSInsetRect(panel.contentView.bounds, kGlow, kGlow);
  [CATransaction commit];
  if (panel.parentWindow != parent) [parent addChildWindow:panel ordered:NSWindowAbove];
  [panel orderFront:nil];
}

void DropPreview::Hide() {
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
}
