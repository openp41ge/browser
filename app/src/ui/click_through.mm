// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/click_through.h"

#import <Cocoa/Cocoa.h>
#include <objc/runtime.h>

#include "include/base/cef_logging.h"

namespace click_through {
namespace {

using AcceptsFirstMouse = BOOL (*)(id, SEL, NSEvent*);

UiAt& Ui() {
  static UiAt ui_at;
  return ui_at;
}

NSHashTable<NSView*>* Allowed() {
  static NSHashTable<NSView*>* allowed = [NSHashTable weakObjectsHashTable];
  return allowed;
}

bool OnUi(NSView* view, NSEvent* event) {
  for (NSView* v = view; v; v = v.superview) {
    if ([Allowed() containsObject:v]) return true;
  }
  NSWindow* window = view.window;
  if (!window || !Ui()) return false;
  // CEF's screen coordinates run down from the main screen's top.
  const NSPoint p = [window convertPointToScreen:event.locationInWindow];
  const CGFloat top = NSScreen.screens.firstObject.frame.size.height;
  return Ui()((__bridge void*)window, CefPoint(static_cast<int>(p.x), static_cast<int>(top - p.y)));
}

// One replacement per class, each calling on to the method it replaced.
template <int kSlot>
struct Replacement {
  static inline AcceptsFirstMouse original = nullptr;
  static BOOL AcceptsFirstMouseOnUi(id self, SEL command, NSEvent* event) {
    return OnUi(self, event) || original(self, command, event);
  }
};

template <int kSlot>
void Replace(NSString* class_name) {
  Class cls = NSClassFromString(class_name);
  Method method = cls ? class_getInstanceMethod(cls, @selector(acceptsFirstMouse:)) : nullptr;
  if (!method) {
    LOG(WARNING) << "Click-through: no " << class_name.UTF8String << " acceptsFirstMouse: to replace";
    return;
  }
  Replacement<kSlot>::original = reinterpret_cast<AcceptsFirstMouse>(method_getImplementation(method));
  IMP replacement = reinterpret_cast<IMP>(&Replacement<kSlot>::AcceptsFirstMouseOnUi);
  // Added to the class itself if it only inherits the method, else replaced.
  if (!class_addMethod(cls, @selector(acceptsFirstMouse:), replacement, method_getTypeEncoding(method))) {
    method_setImplementation(method, replacement);
  }
}

}  // namespace

void Install(UiAt ui_at) {
  if (Ui()) return;
  Ui() = std::move(ui_at);
  Replace<0>(@"RenderWidgetHostViewCocoa");
  Replace<1>(@"BridgedContentView");
}

void Allow(CefWindowHandle view) {
  if (view) [Allowed() addObject:(__bridge NSView*)view];
}

}  // namespace click_through
