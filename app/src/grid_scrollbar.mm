// Copyright (c) 2026 Richard Kielty. MIT License.

#include "grid_scrollbar.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>

namespace {

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}

bool Dark() {
  return [[NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]]
      isEqualToString:NSAppearanceNameDarkAqua];
}

NSColor* Grey(int value, CGFloat alpha = 1) {
  return [NSColor colorWithSRGBRed:value / 255.0 green:value / 255.0 blue:value / 255.0 alpha:alpha];
}

// A transparent, borderless panel that takes the mouse but never the
// keyboard or the app's focus, attached to `parent` so it moves with it.
NSPanel* ControlPanel() {
  NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
  panel.releasedWhenClosed = NO;
  panel.opaque = NO;
  panel.backgroundColor = NSColor.clearColor;
  panel.hasShadow = NO;
  panel.becomesKeyOnlyIfNeeded = YES;
  return panel;
}

}  // namespace

@interface GridScroller : NSView
@property(nonatomic, copy) void (^onScroll)(CGFloat offset);
- (void)setContent:(CGFloat)content viewport:(CGFloat)viewport offset:(CGFloat)offset;
@end

@implementation GridScroller {
  CALayer* _thumb;
  CGFloat _content;
  CGFloat _viewport;
  CGFloat _offset;
  BOOL _dragging;
  CGFloat _grabX;       // Where in the thumb it was grabbed.
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (!self) return nil;
  self.wantsLayer = YES;
  _thumb = [CALayer layer];
  _thumb.cornerRadius = 3;
  [self.layer addSublayer:_thumb];
  [self updateColors];
  return self;
}

// The strip in the gutter colour, the thumb a mid grey.
- (void)updateColors {
  const bool dark = Dark();
  self.layer.backgroundColor = (dark ? Grey(0x16) : Grey(0xf0)).CGColor;
  _thumb.backgroundColor = (dark ? Grey(0x55) : Grey(0xb0)).CGColor;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
  return YES;
}

- (CGFloat)maxOffset {
  return std::max<CGFloat>(0, _content - _viewport);
}

- (NSRect)thumbFrame {
  const CGFloat track = self.bounds.size.width;
  const CGFloat width = std::max<CGFloat>(24, track * _viewport / std::max<CGFloat>(_content, 1));
  const CGFloat x = self.maxOffset > 0 ? (track - width) * _offset / self.maxOffset : 0;
  return NSMakeRect(x, 2, width, self.bounds.size.height - 4);
}

- (void)setContent:(CGFloat)content viewport:(CGFloat)viewport offset:(CGFloat)offset {
  _content = content;
  _viewport = viewport;
  _offset = offset;
  [self updateColors];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  _thumb.frame = self.thumbFrame;
  [CATransaction commit];
}

- (void)scrollTo:(CGFloat)offset {
  offset = std::clamp<CGFloat>(offset, 0, self.maxOffset);
  if (self.onScroll) self.onScroll(offset);
}

- (void)mouseDown:(NSEvent*)event {
  const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  NSRect thumb = self.thumbFrame;
  if (!NSPointInRect(NSMakePoint(p.x, NSMidY(thumb)), thumb)) {
    // On the track: centre the thumb there, then keep dragging it.
    const CGFloat track = self.bounds.size.width - thumb.size.width;
    if (track > 0) [self scrollTo:(p.x - thumb.size.width / 2) / track * self.maxOffset];
    thumb = self.thumbFrame;
  }
  _dragging = YES;
  _grabX = p.x - thumb.origin.x;
}

- (void)mouseDragged:(NSEvent*)event {
  if (!_dragging) return;
  const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  const CGFloat track = self.bounds.size.width - self.thumbFrame.size.width;
  if (track > 0) [self scrollTo:(p.x - _grabX) / track * self.maxOffset];
}

- (void)mouseUp:(NSEvent*)event {
  _dragging = NO;
}

// Sideways scrolling (or a vertical wheel) over the bar scrolls the grid.
- (void)scrollWheel:(NSEvent*)event {
  const CGFloat delta = std::abs(event.scrollingDeltaX) > std::abs(event.scrollingDeltaY) ? event.scrollingDeltaX
                                                                                          : event.scrollingDeltaY;
  [self scrollTo:_offset - delta];
}

@end

struct GridScrollbar::Native {
  NSPanel* panel = nil;  // Holding the GridScroller.
};

GridScrollbar::GridScrollbar(CefRefPtr<CefWindow> window, std::function<void(int)> on_scroll)
    : window_(window), on_scroll_(std::move(on_scroll)), native_(new Native()) {}

GridScrollbar::~GridScrollbar() {
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel close];
  }
}

void GridScrollbar::Update(const CefRect& strip, int content, int viewport, int offset) {
  NSWindow* window = ((__bridge NSView*)window_->GetWindowHandle()).window;
  if (!native_->panel) {
    NSPanel* panel = ControlPanel();
    GridScroller* view = [[GridScroller alloc] initWithFrame:NSZeroRect];
    std::function<void(int)>* on_scroll = &on_scroll_;  // Lives as long as the panel.
    view.onScroll = ^(CGFloat value) { (*on_scroll)(static_cast<int>(value)); };
    panel.contentView = view;
    native_->panel = panel;
  }
  NSPanel* panel = native_->panel;
  [panel setFrame:ToCocoa(strip) display:YES];
  [(GridScroller*)panel.contentView setContent:content viewport:viewport offset:offset];
  if (panel.parentWindow != window) [window addChildWindow:panel ordered:NSWindowAbove];
}

void GridScrollbar::Hide() {
  if (NSPanel* panel = native_->panel) {
    [panel.parentWindow removeChildWindow:panel];
    [panel orderOut:nil];
  }
}
