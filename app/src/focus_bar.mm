// Copyright (c) 2026 Richard Kielty. MIT License.

#include "focus_bar.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

struct FocusBar::Native {
  NSPanel* panel = nil;
  CALayer* bar = nil;
};

FocusBar::FocusBar(CefRefPtr<CefWindow> parent) : parent_(parent), native_(new Native()) {}

FocusBar::~FocusBar() {
  if (native_->panel) {
    [native_->panel.parentWindow removeChildWindow:native_->panel];
    [native_->panel close];
  }
}

void FocusBar::Show(int x, int y, int width) {
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
    // The indicator blue (--border-focus), fully rounded.
    CALayer* bar = [CALayer layer];
    bar.backgroundColor = [NSColor colorWithSRGBRed:74 / 255.0 green:158 / 255.0 blue:1 alpha:1].CGColor;
    bar.cornerRadius = kThickness / 2.0;
    [content.layer addSublayer:bar];
    native_->panel = panel;
    native_->bar = bar;
  }
  NSPanel* panel = native_->panel;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  // CEF screen coordinates have their origin at the top left of the main
  // screen; Cocoa's at the bottom left.
  // A window's frame is in whole points, and the bar's middle is on a whole
  // point (the edge): so the panel is the bar's thickness either side of the
  // edge, and the bar half a point in from its bottom (drawn at the
  // display's resolution).
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  [panel setFrame:NSMakeRect(x, screen_height - y - kThickness, width, 2 * kThickness) display:NO];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  native_->bar.frame = CGRectMake(0, kThickness / 2.0, width, kThickness);
  [CATransaction commit];
  if (panel.parentWindow != parent) [parent addChildWindow:panel ordered:NSWindowAbove];
  if (!panel.visible) [panel orderFront:nil];
}

void FocusBar::Hide() {
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
}
