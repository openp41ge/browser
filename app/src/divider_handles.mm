// Copyright (c) 2026 Richard Kielty. MIT License.

#include "divider_handles.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

namespace {

constexpr CGFloat kHandleWidth = 5;
constexpr CGFloat kLineWidth = 3;

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
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
  // Every click in its bounds, transparent or not. By default macOS passes
  // clicks on a window's transparent parts through to the window below, so
  // a click beside the blue line (or while it was still fading in) reached
  // the page instead, though the line showed: hover and clicks now cover
  // the same 5px.
  panel.ignoresMouseEvents = NO;
  return panel;
}

}  // namespace

@interface DividerHandle : NSView
@property(nonatomic) int index;
@property(nonatomic, copy) void (^onBegin)(int index, int screenX);
@property(nonatomic, copy) void (^onMove)(int screenX);
@property(nonatomic, copy) void (^onEnd)(void);
@property(nonatomic, copy) void (^onReset)(void);
@end

@implementation DividerHandle {
  CALayer* _line;
  BOOL _hover;
  BOOL _dragging;
}

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (!self) return nil;
  self.wantsLayer = YES;
  _line = [CALayer layer];
  _line.backgroundColor = [NSColor colorWithSRGBRed:74 / 255.0 green:158 / 255.0 blue:1 alpha:1].CGColor;
  _line.opacity = 0;
  [self.layer addSublayer:_line];
  [self addTrackingArea:[[NSTrackingArea alloc]
                            initWithRect:NSZeroRect
                                 options:NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate |
                                         NSTrackingActiveAlways | NSTrackingInVisibleRect
                                   owner:self
                                userInfo:nil]];
  return self;
}

- (void)setFrameSize:(NSSize)size {
  [super setFrameSize:size];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  _line.frame = NSMakeRect((self.bounds.size.width - kLineWidth) / 2, 0, kLineWidth, self.bounds.size.height);
  [CATransaction commit];
}

// The blue line fades in on hover or while dragging (0.12s, as openp41ge).
- (void)updateLine {
  [CATransaction begin];
  [CATransaction setAnimationDuration:0.12];
  _line.opacity = _hover || _dragging ? 1 : 0;
  [CATransaction commit];
}

- (void)cursorUpdate:(NSEvent*)event {
  [NSCursor.resizeLeftRightCursor set];
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
  return YES;
}

- (void)mouseEntered:(NSEvent*)event {
  _hover = YES;
  [self updateLine];
}

- (void)mouseExited:(NSEvent*)event {
  _hover = NO;
  [self updateLine];
}

- (void)mouseDown:(NSEvent*)event {
  if (event.clickCount == 2) {
    if (self.onReset) self.onReset();
    return;
  }
  _dragging = YES;
  [self updateLine];
  if (self.onBegin) self.onBegin(self.index, static_cast<int>(NSEvent.mouseLocation.x));
}

- (void)mouseDragged:(NSEvent*)event {
  if (_dragging && self.onMove) self.onMove(static_cast<int>(NSEvent.mouseLocation.x));
}

- (void)mouseUp:(NSEvent*)event {
  if (!_dragging) return;
  _dragging = NO;
  [self updateLine];
  if (self.onEnd) self.onEnd();
}

@end

struct DividerHandles::Native {
  NSMutableArray<NSPanel*>* panels = [NSMutableArray array];  // Each holding a DividerHandle.
};

DividerHandles::DividerHandles(CefRefPtr<CefWindow> window, Callbacks callbacks)
    : window_(window), callbacks_(std::move(callbacks)), native_(new Native()) {}

DividerHandles::~DividerHandles() {
  for (NSPanel* panel in native_->panels) {
    [panel.parentWindow removeChildWindow:panel];
    [panel close];
  }
}

void DividerHandles::Update(const std::vector<CefRect>& lines) {
  NSWindow* window = ((__bridge NSView*)window_->GetWindowHandle()).window;
  while (native_->panels.count > lines.size()) {
    NSPanel* panel = native_->panels.lastObject;
    [panel.parentWindow removeChildWindow:panel];
    [panel close];
    [native_->panels removeLastObject];
  }
  while (native_->panels.count < lines.size()) {
    NSPanel* panel = ControlPanel();
    DividerHandle* handle = [[DividerHandle alloc] initWithFrame:NSZeroRect];
    Callbacks* callbacks = &callbacks_;  // Lives as long as the panels.
    handle.onBegin = ^(int index, int x) { callbacks->begin(index, x); };
    handle.onMove = ^(int x) { callbacks->move(x); };
    handle.onEnd = ^{ callbacks->end(); };
    handle.onReset = ^{ callbacks->reset(); };
    panel.contentView = handle;
    [native_->panels addObject:panel];
  }
  for (size_t i = 0; i < lines.size(); ++i) {
    NSPanel* panel = native_->panels[i];
    ((DividerHandle*)panel.contentView).index = static_cast<int>(i);
    // Centred on the line.
    NSRect frame = ToCocoa(lines[i]);
    frame.origin.x += frame.size.width / 2 - kHandleWidth / 2;
    frame.size.width = kHandleWidth;
    [panel setFrame:frame display:YES];
    if (panel.parentWindow != window) [window addChildWindow:panel ordered:NSWindowAbove];
  }
}
