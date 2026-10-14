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
//
// It closes the CEF way: a close request (the page calling window.close(),
// or our own CloseBrowser, via CEF's DoClose) asks `canClose`, which lets
// the page run its unload handlers first.
@interface PopoutWindow : NSWindow
@property(nonatomic, copy) BOOL (^canClose)(void);
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

// Frameless windows have no close button, so AppKit's own performClose:
// would just beep.
- (void)performClose:(id)sender {
  if (!self.canClose || self.canClose()) [self close];
}

// Closing tears down the page's view, which is what lets CEF finish closing
// the page (OnBeforeClose).
- (void)close {
  [super close];
  self.contentView = nil;
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
  int frame_applied = 0;  // The last frame request applied (core.js counts them).
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

// A number from JSON: whole numbers parse as ints, others as doubles.
double Number(CefRefPtr<CefListValue> list, size_t index) {
  return list->GetType(index) == VTYPE_INT ? list->GetInt(index) : list->GetDouble(index);
}

// CEF screen rectangles have their origin at the top left of the main
// screen; Cocoa's at the bottom left.
NSRect ToCocoa(double x, double y, double width, double height) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(x, screen_height - y - height, width, height);
}

// The frame core.js asks for, from the pop-out's document (it's DOM, so the
// page's main world sees it whichever world opened the window).
constexpr char kFrameRequest[] =
    "documentPictureInPicture.window?.document.documentElement.dataset.openp41geFrame ?? null";
// How often an open pop-out's frame requests are checked.
constexpr int64_t kFrameWatchMs = 200;

CefRefPtr<CefDictionaryValue> ParseFrame(CefRefPtr<CefValue> value) {
  CefRefPtr<CefValue> parsed =
      value && value->GetType() == VTYPE_STRING ? CefParseJSON(value->GetString(), JSON_PARSER_RFC) : nullptr;
  CefRefPtr<CefDictionaryValue> frame = parsed ? parsed->GetDictionary() : nullptr;
  return frame && frame->HasKey("width") && frame->HasKey("height") ? frame : nullptr;
}

double Number(CefRefPtr<CefDictionaryValue> dict, const char* key) {
  return dict->GetType(key) == VTYPE_INT ? dict->GetInt(key) : dict->GetDouble(key);
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
  CefRefPtr<PopoutController> self(this);
  window.canClose = ^BOOL {
    if (!self->window_) return YES;
    CefRefPtr<CefBrowserHost> host = self->window_->GetHost();
    return host->IsReadyToBeClosed() || host->TryCloseBrowser();
  };
  // On screen but invisible until it's placed (Place): the page inside is
  // laid out at the window's size only once the window is on screen.
  window.alphaValue = 0;
  [window orderFront:nil];
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
  // core.js asks for a frame once the window exists (kFrameRequest).
  devtools_->Evaluate(
      source_, kFrameRequest, {}, [self, attempts_left](CefRefPtr<CefValue> value) {
        PopoutWindow* window = self->native_->window;
        if (!window || !self->source_) return;
        CefRefPtr<CefDictionaryValue> where = ParseFrame(value);
        if (!where || !where->HasKey("anchor")) {
          if (attempts_left > 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
              self->Place(attempts_left - 1);
            });
          } else {
            [window center];
            window.alphaValue = 1;
            [window makeKeyAndOrderFront:nil];
          }
          return;
        }
        const double width = Number(where, "width");
        const double height = Number(where, "height");
        CefRefPtr<CefDictionaryValue> anchor = where->GetDictionary("anchor");
        double x = 0, y = 0;
        if (anchor->HasKey("screen")) {
          x = Number(anchor->GetList("screen"), 0);
          y = Number(anchor->GetList("screen"), 1);
        } else if (CefRefPtr<CefBrowserView> view = CefBrowserView::GetForBrowser(self->source_)) {
          // The element's position in its page, plus the page's on screen.
          const CefRect page = view->GetBoundsInScreen();
          x = page.x + Number(anchor->GetList("viewport"), 0);
          y = page.y + Number(anchor->GetList("viewport"), 1);
        }
        [window setFrame:ToCocoa(x, y, width, height) display:YES];
        window.contentAspectRatio = NSMakeSize(width, height);
        window.alphaValue = 1;
        [window makeKeyAndOrderFront:nil];
        self->native_->frame_applied = where->GetInt("n");
        self->WatchFrame();
      });
}

void PopoutController::WatchFrame() {
  if (!window_ || !source_ || !native_->window) return;
  CefRefPtr<PopoutController> self(this);
  PopoutWindow* watched = native_->window;
  devtools_->Evaluate(source_, kFrameRequest, {}, [self, watched](CefRefPtr<CefValue> value) {
    PopoutWindow* window = self->native_->window;
    // Closed, or another pop-out since.
    if (!window || window != watched || !self->source_) return;
    CefRefPtr<CefDictionaryValue> frame = ParseFrame(value);
    if (frame && frame->GetInt("n") > self->native_->frame_applied) {
      self->native_->frame_applied = frame->GetInt("n");
      const double width = Number(frame, "width");
      const double height = Number(frame, "height");
      // Where it asks, else its top-left stays where it is.
      const NSRect current = window.frame;
      const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
      const double x = frame->HasKey("x") ? Number(frame, "x") : current.origin.x;
      const double y = frame->HasKey("y") ? Number(frame, "y") : screen_height - NSMaxY(current);
      window.contentAspectRatio = NSMakeSize(width, height);
      [window setFrame:ToCocoa(x, y, width, height) display:YES animate:NO];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kFrameWatchMs * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      self->WatchFrame();
    });
  });
}

void PopoutController::OnWindowClosed() {
  CefRefPtr<CefBrowser> source = source_;
  native_->frame_applied = 0;
  window_ = nullptr;
  source_ = nullptr;
  if (PopoutWindow* window = native_->window) {
    native_->window = nil;
    window.canClose = nil;
    [window close];
  }
  if (observer_) observer_->OnPopoutClosed(source);
}
