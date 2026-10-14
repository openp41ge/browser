// Copyright (c) 2026 Richard Kielty. MIT License.

#include "focus_bar.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <cmath>

namespace {

// How far above and below the thin bar the pointer counts as over it (it's
// only 3pt).
constexpr CGFloat kHoverSlop = 3;

}  // namespace

struct FocusBar::Native {
  NSPanel* panel = nil;
  CALayer* bar = nil;
  CATextLayer* label = nil;
  id monitor = nil;
  bool grown = false;

  // The bar's frame in the panel: thin (in from its sides), or grown to
  // fill it.
  void Layout(bool animate) {
    const CGFloat inset = grown ? 0 : kGrownOutset;
    const CGFloat width = panel.frame.size.width - 2 * inset;
    [CATransaction begin];
    if (animate) {
      [CATransaction setAnimationDuration:0.15];
      [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    } else {
      [CATransaction setDisableActions:YES];
    }
    const CGFloat height = grown ? kGrownThickness : kThickness;
    bar.frame = CGRectMake(inset, (kGrownThickness - height) / 2, width, height);
    bar.cornerRadius = height / 2;
    label.frame = CGRectMake(0, (height - label.preferredFrameSize.height) / 2, width, label.preferredFrameSize.height);
    label.opacity = grown ? 1 : 0;
    [CATransaction commit];
  }

  // Grows or shrinks it for where the pointer is.
  void Track() {
    if (!panel.visible) return;
    // Where the bar is, as it's shown.
    const NSRect frame = grown ? panel.frame : NSInsetRect(panel.frame, kGrownOutset, 0);
    const NSPoint at = NSEvent.mouseLocation;
    const CGFloat reach = grown ? kGrownThickness / 2.0 : kThickness / 2.0 + kHoverSlop;
    const bool over = at.x >= NSMinX(frame) && at.x < NSMaxX(frame) && std::abs(at.y - NSMidY(frame)) <= reach;
    if (over == grown) return;
    grown = over;
    Layout(true);
  }
};

FocusBar::FocusBar(CefRefPtr<CefWindow> parent) : parent_(parent), native_(new Native()) {}

FocusBar::~FocusBar() {
  if (native_->monitor) [NSEvent removeMonitor:native_->monitor];
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
    bar.masksToBounds = YES;
    [content.layer addSublayer:bar];
    CATextLayer* label = [CATextLayer layer];
    // Capitals, a size down and spaced a little, as small labels are.
    label.string = [[NSAttributedString alloc]
        initWithString:@"FOCUSED"
            attributes:@{
              NSFontAttributeName : [NSFont systemFontOfSize:9 weight:NSFontWeightSemibold],
              NSForegroundColorAttributeName : NSColor.whiteColor,
              NSKernAttributeName : @0.4,
            }];
    label.alignmentMode = kCAAlignmentCenter;
    [bar addSublayer:label];
    native_->panel = panel;
    native_->bar = bar;
    native_->label = label;
    // The pointer as it moves over our windows (the panel itself ignores
    // the mouse).
    Native* native = native_.get();
    native_->monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged
                                                             handler:^NSEvent*(NSEvent* event) {
                                                               native->Track();
                                                               return event;
                                                             }];
  }
  NSPanel* panel = native_->panel;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  // CEF screen coordinates have their origin at the top left of the main
  // screen; Cocoa's at the bottom left.
  // A window's frame is in whole points, and the bar's middle is on a whole
  // point (the edge): so the panel is the grown bar's size, centred on the
  // edge, and the thin bar is half a point off whole points (drawn at the
  // display's resolution).
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  [panel setFrame:NSMakeRect(x - kGrownOutset, screen_height - y - kGrownThickness / 2, width + 2 * kGrownOutset,
                             kGrownThickness)
          display:NO];
  native_->label.contentsScale = parent.backingScaleFactor;
  native_->Layout(false);
  if (panel.parentWindow != parent) [parent addChildWindow:panel ordered:NSWindowAbove];
  if (!panel.visible) [panel orderFront:nil];
  // It may have moved under (or out from under) the pointer.
  native_->Track();
}

void FocusBar::Hide() {
  native_->grown = false;
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
}
