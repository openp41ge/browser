// Copyright (c) 2026 Richard Kielty. MIT License.

#include "tab_drag_image.h"

#import <Cocoa/Cocoa.h>

namespace {

constexpr CGFloat kWidth = 320;
constexpr CGFloat kHeader = 34;
constexpr CGFloat kBodyHeight = 200;  // Until the snapshot gives the page's shape.
constexpr CGFloat kMaxBodyHeight = 240;
constexpr CGFloat kShadow = 16;  // Room around the card for its shadow.

NSColor* Rgb(int r, int g, int b) {
  return [NSColor colorWithSRGBRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1];
}

// CEF screen coordinates have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSPoint ToCocoa(const CefPoint& p) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakePoint(p.x, screen_height - p.y);
}

}  // namespace

struct TabDragImage::Native {
  NSPanel* panel = nil;
  NSView* card = nil;
  NSImageView* snapshot = nil;
  CGFloat body_height = kBodyHeight;
  CefPoint at;

  void Layout() {
    const CGFloat height = kHeader + body_height;
    NSRect frame = panel.frame;
    frame.size = NSMakeSize(kWidth + 2 * kShadow, height + 2 * kShadow);
    [panel setFrame:frame display:NO];
    card.frame = NSMakeRect(kShadow, kShadow, kWidth, height);
    snapshot.frame = NSMakeRect(0, 0, kWidth, body_height);
  }
};

TabDragImage::TabDragImage(const std::string& title) : native_(new Native()) {
  NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
  panel.releasedWhenClosed = NO;
  panel.opaque = NO;
  panel.backgroundColor = NSColor.clearColor;
  panel.hasShadow = NO;  // The card draws its own (the panel is larger than it).
  panel.ignoresMouseEvents = YES;
  panel.level = NSPopUpMenuWindowLevel;
  panel.alphaValue = 0.94;
  panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient;

  // The card: the tab (the browser's dark UI, the focused tab's blue bar
  // along its top: half its width, centred, rounded) over the page.
  NSView* card = [[NSView alloc] initWithFrame:NSZeroRect];
  card.wantsLayer = YES;
  card.layer.backgroundColor = Rgb(0x16, 0x16, 0x16).CGColor;
  card.layer.cornerRadius = 8;
  card.layer.borderWidth = 1;
  card.layer.borderColor = Rgb(0x33, 0x33, 0x33).CGColor;
  card.layer.masksToBounds = YES;
  card.autoresizingMask = NSViewNotSizable;

  NSView* header = [[NSView alloc] initWithFrame:NSZeroRect];
  header.wantsLayer = YES;
  header.layer.backgroundColor = Rgb(0x2d, 0x2d, 0x2d).CGColor;
  header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  CALayer* line = [CALayer layer];
  line.backgroundColor = Rgb(74, 158, 255).CGColor;
  line.frame = CGRectMake(kWidth / 4, kHeader - 3, kWidth / 2, 3);
  line.cornerRadius = 1.5;
  [header.layer addSublayer:line];
  NSTextField* label = [NSTextField labelWithString:@(title.c_str())];
  label.font = [NSFont systemFontOfSize:12];
  label.textColor = Rgb(0xd4, 0xd4, 0xd4);
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  label.frame = NSMakeRect(12, (kHeader - 16) / 2 - 1, kWidth - 24, 16);
  [header addSubview:label];

  NSImageView* snapshot = [[NSImageView alloc] initWithFrame:NSZeroRect];
  snapshot.imageScaling = NSImageScaleProportionallyUpOrDown;
  snapshot.imageAlignment = NSImageAlignTop;

  [card addSubview:snapshot];
  [card addSubview:header];
  NSView* content = panel.contentView;
  content.wantsLayer = YES;
  content.layer.shadowColor = NSColor.blackColor.CGColor;
  content.layer.shadowOpacity = 0.45;
  content.layer.shadowRadius = 10;
  content.layer.shadowOffset = CGSizeMake(0, -3);
  [content addSubview:card];

  native_->panel = panel;
  native_->card = card;
  native_->snapshot = snapshot;
  native_->Layout();
  header.frame = NSMakeRect(0, native_->body_height, kWidth, kHeader);
}

TabDragImage::~TabDragImage() {
  [native_->panel orderOut:nil];
  [native_->panel close];
}

void TabDragImage::SetSnapshot(const std::string& encoded) {
  NSData* data = [NSData dataWithBytes:encoded.data() length:encoded.size()];
  NSImage* image = [[NSImage alloc] initWithData:data];
  if (!image || image.size.width <= 0) return;
  native_->snapshot.image = image;
  // The body takes the page's shape (within limits).
  native_->body_height = std::min(kMaxBodyHeight, kWidth * image.size.height / image.size.width);
  NSView* header = native_->card.subviews.lastObject;
  native_->Layout();
  header.frame = NSMakeRect(0, native_->body_height, kWidth, kHeader);
  MoveTo(native_->at);
}

void TabDragImage::MoveTo(const CefPoint& screen) {
  native_->at = screen;
  // The pointer on the tab: kGrabX in, kGrabY down from the card's top left.
  const NSPoint p = ToCocoa(screen);
  const NSSize size = native_->panel.frame.size;
  const NSPoint origin = NSMakePoint(p.x - kGrabX - kShadow, p.y + kGrabY + kShadow - size.height);
  [native_->panel setFrameOrigin:origin];
  if (!native_->panel.visible) [native_->panel orderFront:nil];
}
