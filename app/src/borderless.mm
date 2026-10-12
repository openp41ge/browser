// Copyright (c) 2026 Richard Kielty. MIT License.

#include "borderless.h"

#import <Cocoa/Cocoa.h>

void MakeBorderless(CefRefPtr<CefWindow> window) {
  NSWindow* native = ((__bridge NSView*)window->GetWindowHandle()).window;
  native.styleMask = NSWindowStyleMaskBorderless;
}
