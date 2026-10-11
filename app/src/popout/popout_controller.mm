// Copyright (c) 2026 Richard Kielty. MIT License.

#include "popout/popout_controller.h"

#import <Cocoa/Cocoa.h>
#include <dispatch/dispatch.h>

#include <vector>

#include "include/cef_parser.h"
#include "include/views/cef_browser_view.h"
#include "include/wrapper/cef_helpers.h"

#include "popout/popout_scripts.h"

// The pop-out's window: frameless, floating above other windows (also over
// full-screen apps), resizable at its edges. It can take the keyboard (for
// the element's own shortcuts). A mouse-down in one of the page's
// -webkit-app-region: drag areas moves it.
@interface PopoutWindow : NSWindow
- (void)setDragRegions:(const std::vector<CefDraggableRegion>&)regions;
@end

@implementation PopoutWindow {
  std::vector<CefDraggableRegion> _regions;
}

- (BOOL)canBecomeKeyWindow {
  return YES;
}

- (void)setDragRegions:(const std::vector<CefDraggableRegion>&)regions {
  _regions = regions;
}

// Draggable areas, minus any non-draggable area on top of them (as Chromium
// reads app-region).
- (BOOL)isDragPoint:(NSPoint)point {
  const int x = static_cast<int>(point.x);
  const int y = static_cast<int>(self.contentView.bounds.size.height - point.y);
  bool drag = false;
  for (const CefDraggableRegion& region : _regions) {
    const CefRect& r = region.bounds;
    if (x < r.x || y < r.y || x >= r.x + r.width || y >= r.y + r.height) continue;
    if (!region.draggable) return NO;
    drag = true;
  }
  return drag;
}

- (void)sendEvent:(NSEvent*)event {
  if (event.type == NSEventTypeLeftMouseDown && [self isDragPoint:event.locationInWindow]) {
    [self performWindowDragWithEvent:event];
    return;
  }
  [super sendEvent:event];
}

@end

struct PopoutController::Native {
  PopoutWindow* window = nil;
};

namespace {

std::string ToJson(CefRefPtr<CefValue> value) {
  return CefWriteJSON(value, JSON_WRITER_DEFAULT).ToString();
}

std::string OptionsJson(const PopoutController::Options& options) {
  CefRefPtr<CefDictionaryValue> dict = CefDictionaryValue::Create();
  dict->SetString("selector", options.selector);
  dict->SetBool("play", options.play);
  if (options.place) {
    CefRefPtr<CefListValue> place = CefListValue::Create();
    place->SetInt(0, options.place->x);
    place->SetInt(1, options.place->y);
    place->SetInt(2, options.place->width);
    dict->SetList("place", place);
  }
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(dict);
  return ToJson(value);
}

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(double x, double y, double width, double height) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(x, screen_height - y - height, width, height);
}

}  // namespace

// The pop-out page's client: follows its life span and drag areas.
class PopoutController::WindowClient : public CefClient, public CefDragHandler, public CefLifeSpanHandler {
 public:
  explicit WindowClient(PopoutController* controller) : controller_(controller) {}

  CefRefPtr<CefDragHandler> GetDragHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }

  void OnDraggableRegionsChanged(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 const std::vector<CefDraggableRegion>& regions) override {
    if (controller_->native_->window) [controller_->native_->window setDragRegions:regions];
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override { controller_->OnWindowCreated(browser); }
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override { controller_->OnWindowClosed(); }

 private:
  // The controller lives as long as the app, and owns this client.
  PopoutController* controller_;
  IMPLEMENT_REFCOUNTING(WindowClient);
};

PopoutController::PopoutController(CefRefPtr<DevToolsClient> devtools, Observer* observer)
    : devtools_(devtools), observer_(observer), window_client_(new WindowClient(this)), native_(new Native()) {}

PopoutController::~PopoutController() = default;

void PopoutController::PopOut(CefRefPtr<CefBrowser> page, const Options& options, DoneCallback done) {
  CEF_REQUIRE_UI_THREAD();
  if (IsOpen() || pending_source_) {
    if (done) done("already-open");
    return;
  }
  // Document PiP needs a user gesture; run it as one.
  devtools_->Evaluate(page, popout_scripts::Library() + "\n__openp41ge.popout(" + OptionsJson(options) + ")",
                      {.user_gesture = true, .await_promise = true},
                      [done](CefRefPtr<CefValue> outcome) {
                        if (!done) return;
                        done(outcome && outcome->GetType() == VTYPE_STRING ? outcome->GetString().ToString()
                                                                         : "failed");
                      });
}

void PopoutController::Close() {
  CEF_REQUIRE_UI_THREAD();
  if (window_) window_->GetHost()->CloseBrowser(false);
}

void PopoutController::Toggle(CefRefPtr<CefBrowser> page) {
  if (IsOpen()) {
    Close();
  } else if (page) {
    PopOut(page, {}, [](const std::string& outcome) {
      LOG_IF(WARNING, outcome != "opened") << "Pop-out: " << outcome;
    });
  }
}

std::string PopoutController::ScriptForNewPages() const {
  return IsOpen() ? popout_scripts::HoldAutoplay() : std::string();
}

bool PopoutController::OnBeforePopup(CefRefPtr<CefBrowser> opener,
                                     cef_window_open_disposition_t disposition,
                                     CefWindowInfo& window_info,
                                     CefRefPtr<CefClient>& client) {
  CEF_REQUIRE_UI_THREAD();
  if (disposition != CEF_WOD_NEW_PICTURE_IN_PICTURE) return false;
  // Our window, shown once it's been placed over the element (Place).
  const NSRect frame = NSMakeRect(0, 0, 320, 180);
  PopoutWindow* window = [[PopoutWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  window.releasedWhenClosed = NO;
  window.level = NSFloatingWindowLevel;
  window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
  window.backgroundColor = NSColor.blackColor;
  native_->window = window;
  window_info.SetAsChild((__bridge CefWindowHandle)window.contentView, CefRect(0, 0, 320, 180));
  pending_source_ = opener;
  client = window_client_;
  return true;
}

void PopoutController::OnWindowCreated(CefRefPtr<CefBrowser> window) {
  window_ = window;
  source_ = pending_source_;
  pending_source_ = nullptr;
  NSView* page = (__bridge NSView*)window->GetHost()->GetWindowHandle();
  page.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  Place(10);
  if (observer_) observer_->OnPopoutOpened(source_);
}

void PopoutController::Place(int attempts_left) {
  if (!window_ || !source_ || !native_->window) return;
  CefRefPtr<PopoutController> self(this);
  // core.js records where the window should go once the window exists.
  devtools_->Evaluate(
      source_,
      "(() => { const c = globalThis.__openp41ge?.current;"
      " return c?.anchor ? JSON.stringify({ anchor: c.anchor, size: c.size }) : null; })()",
      {}, [self, attempts_left](CefRefPtr<CefValue> value) {
        PopoutWindow* window = self->native_->window;
        if (!window || !self->source_) return;
        CefRefPtr<CefValue> parsed =
            value && value->GetType() == VTYPE_STRING ? CefParseJSON(value->GetString(), JSON_PARSER_RFC) : nullptr;
        CefRefPtr<CefDictionaryValue> where = parsed ? parsed->GetDictionary() : nullptr;
        if (!where) {
          if (attempts_left > 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
              self->Place(attempts_left - 1);
            });
          } else {
            [window center];
            [window makeKeyAndOrderFront:nil];
          }
          return;
        }
        CefRefPtr<CefListValue> size = where->GetList("size");
        const double width = size->GetDouble(0);
        const double height = size->GetDouble(1);
        CefRefPtr<CefDictionaryValue> anchor = where->GetDictionary("anchor");
        double x = 0, y = 0;
        if (anchor->HasKey("screen")) {
          x = anchor->GetList("screen")->GetDouble(0);
          y = anchor->GetList("screen")->GetDouble(1);
        } else if (CefRefPtr<CefBrowserView> view = CefBrowserView::GetForBrowser(self->source_)) {
          // The element's position in its page, plus the page's on screen.
          const CefRect page = view->GetBoundsInScreen();
          x = page.x + anchor->GetList("viewport")->GetDouble(0);
          y = page.y + anchor->GetList("viewport")->GetDouble(1);
        }
        [window setFrame:ToCocoa(x, y, width, height) display:YES];
        window.contentAspectRatio = NSMakeSize(width, height);
        [window makeKeyAndOrderFront:nil];
      });
}

void PopoutController::OnWindowClosed() {
  CefRefPtr<CefBrowser> source = source_;
  window_ = nullptr;
  source_ = nullptr;
  if (native_->window) {
    [native_->window orderOut:nil];
    [native_->window close];
    native_->window = nil;
  }
  if (observer_) observer_->OnPopoutClosed(source);
}
