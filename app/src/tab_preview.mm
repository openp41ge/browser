// Copyright (c) 2026 Richard Kielty. MIT License.

#include "tab_preview.h"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <algorithm>
#include <cmath>
#include <memory>

namespace {

constexpr CGFloat kFooterHeight = 24;
constexpr CGFloat kRadius = 8;
// The picture's shape, height over width (16:10), whatever the page's: a
// narrow column's tall pages would otherwise make tall previews.
constexpr CGFloat kAspect = 10.0 / 16.0;
constexpr NSTimeInterval kFadeIn = 0.15;
constexpr NSTimeInterval kFadeOut = 0.1;

NSColor* Rgb(int r, int g, int b) {
  return [NSColor colorWithSRGBRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1];
}

// The top of the page, in the picture's shape (kAspect): a tall page cut off
// at its bottom, a wide one at its sides.
NSImage* TopOf(NSImage* picture) {
  CGImageRef image = [picture CGImageForProposedRect:nullptr context:nil hints:nil];
  if (!image) return picture;
  const CGFloat w = CGImageGetWidth(image);
  const CGFloat h = CGImageGetHeight(image);
  const CGRect crop = h / w > kAspect ? CGRectMake(0, 0, w, std::round(w * kAspect))
                                      : CGRectMake(std::round((w - h / kAspect) / 2), 0, std::round(h / kAspect), h);
  CGImageRef cropped = CGImageCreateWithImageInRect(image, crop);
  if (!cropped) return picture;
  NSImage* top = [[NSImage alloc] initWithCGImage:cropped size:NSZeroSize];
  CGImageRelease(cropped);
  return top;
}

}  // namespace

struct TabPreview::Native {
  NSPanel* panel = nil;
  NSView* card = nil;
  NSImageView* image = nil;
  NSView* footer = nil;
  NSTextField* footer_label = nil;
  bool shown = false;
  // Counts shows and hides, so a finished fade-out doesn't hide a newer
  // show. Shared with the fade-out's completion, which may outlive this.
  std::shared_ptr<int> serial = std::make_shared<int>(0);
};

TabPreview::TabPreview() : native_(new Native()) {
  NSPanel* panel = [[NSPanel alloc] initWithContentRect:NSZeroRect
                                              styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
  panel.releasedWhenClosed = NO;
  panel.opaque = NO;
  panel.backgroundColor = NSColor.clearColor;
  // The system's shadow, which follows the card's shape (rounded corners
  // and all) and goes with the window.
  panel.hasShadow = YES;
  panel.ignoresMouseEvents = YES;
  panel.level = NSPopUpMenuWindowLevel;
  panel.alphaValue = 0;
  panel.collectionBehavior = NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorIgnoresCycle;

  // The card: the picture, with a border in the UI's colours; which corners
  // are rounded is set as it shows.
  NSView* card = [[NSView alloc] initWithFrame:NSZeroRect];
  card.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  card.wantsLayer = YES;
  card.layer.backgroundColor = Rgb(0x16, 0x16, 0x16).CGColor;
  card.layer.cornerRadius = kRadius;
  card.layer.borderWidth = 1;
  card.layer.borderColor = Rgb(0x33, 0x33, 0x33).CGColor;
  card.layer.masksToBounds = YES;
  NSImageView* image = [[NSImageView alloc] initWithFrame:NSZeroRect];
  // Cut to the picture's shape already (TopOf): it fills it.
  image.imageScaling = NSImageScaleAxesIndependently;
  [card addSubview:image];
  // The bar under the picture: the tab bar's colours.
  NSView* footer = [[NSView alloc] initWithFrame:NSZeroRect];
  footer.wantsLayer = YES;
  footer.layer.backgroundColor = Rgb(0x2d, 0x2d, 0x2d).CGColor;
  NSTextField* footer_label = [NSTextField labelWithString:@""];
  footer_label.font = [NSFont systemFontOfSize:11];
  footer_label.textColor = Rgb(0x99, 0x99, 0x99);
  footer_label.lineBreakMode = NSLineBreakByTruncatingTail;
  [footer addSubview:footer_label];
  [card addSubview:footer];

  // The window is the card's size: nothing around it to leave behind.
  NSView* content = panel.contentView;
  content.wantsLayer = YES;
  card.frame = content.bounds;
  [content addSubview:card];

  native_->panel = panel;
  native_->card = card;
  native_->image = image;
  native_->footer = footer;
  native_->footer_label = footer_label;
}

TabPreview::~TabPreview() {
  [native_->panel orderOut:nil];
  [native_->panel close];
}

void TabPreview::Show(const std::string& jpeg,
                      const CefRect& anchor,
                      bool square_left,
                      bool square_right,
                      const std::string& footer) {
  NSData* data = [NSData dataWithBytes:jpeg.data() length:jpeg.size()];
  NSImage* picture = [[NSImage alloc] initWithData:data];
  if (!picture || picture.size.width <= 0 || anchor.width <= 0) return;
  ++*native_->serial;

  // The tab's width; the picture in its shape (its height follows the
  // width), the bar under it.
  const CGFloat width = anchor.width;
  const CGFloat picture_height = std::round(width * kAspect);
  const CGFloat footer_height = footer.empty() ? 0 : kFooterHeight;
  const CGFloat height = picture_height + footer_height;
  native_->image.image = TopOf(picture);
  native_->image.frame = NSMakeRect(0, footer_height, width, picture_height);
  native_->footer.hidden = footer.empty();
  native_->footer.frame = NSMakeRect(0, 0, width, footer_height);
  native_->footer_label.stringValue = @(footer.c_str());
  native_->footer_label.frame = NSMakeRect(10, (footer_height - 15) / 2, std::max<CGFloat>(width - 20, 0), 15);
  // Rounded at the bottom (in the layer's coordinates, y up: MinY), but not
  // on a side that meets the column's edge.
  CACornerMask corners = 0;
  if (!square_left) corners |= kCALayerMinXMinYCorner;
  if (!square_right) corners |= kCALayerMaxXMinYCorner;
  native_->card.layer.maskedCorners = corners;

  // Hanging from the tab bar's bottom edge, under the tab. CEF screen
  // coordinates have their origin at the top left of the main screen;
  // Cocoa's at the bottom left.
  const CGFloat main_height = NSScreen.screens.firstObject.frame.size.height;
  const CGFloat bar_bottom = main_height - (anchor.y + anchor.height);
  [native_->panel setFrame:NSMakeRect(anchor.x, bar_bottom - height, width, height) display:NO];
  native_->card.frame = native_->panel.contentView.bounds;
  [native_->panel display];
  // Its shadow, for the new shape.
  [native_->panel invalidateShadow];

  if (!native_->shown) {
    native_->shown = true;
    [native_->panel orderFront:nil];
  }
  // Fade in (from where a fade-out had got to, if it was going).
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
    context.duration = kFadeIn;
    context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    native_->panel.animator.alphaValue = 1;
  }];
}

void TabPreview::Hide() {
  if (!native_->shown) return;
  native_->shown = false;
  const int serial = ++*native_->serial;
  std::shared_ptr<int> current = native_->serial;
  NSPanel* panel = native_->panel;
  [NSAnimationContext
      runAnimationGroup:^(NSAnimationContext* context) {
        context.duration = kFadeOut;
        panel.animator.alphaValue = 0;
      }
      completionHandler:^{
        // Unless it was shown again meanwhile.
        if (*current == serial) [panel orderOut:nil];
      }];
}
