// Copyright (c) 2026 Richard Kielty. MIT License.

#include "menu_window.h"

#import <Cocoa/Cocoa.h>

#include "include/base/cef_callback.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

namespace {

// The open menu, if any (one at a time).
CefRefPtr<MenuWindow> g_open;

// Room the page may not have reported yet: the window starts this size,
// hidden, until the page says how big it is.
constexpr int kInitialWidth = 240;
constexpr int kInitialHeight = 100;

// CEF screen coordinates (origin at the main screen's top left) as a Cocoa
// frame (origin at its bottom left).
NSRect ToFrame(const CefRect& r) {
  const CGFloat screen_height = NSScreen.screens.firstObject.frame.size.height;
  return NSMakeRect(r.x, screen_height - r.y - r.height, r.width, r.height);
}

}  // namespace

// Borderless, and still able to take the keyboard (arrows, Return, Escape);
// it says when it loses it.
@interface MenuNSWindow : NSWindow <NSWindowDelegate>
@property(nonatomic, copy) void (^onResignKey)(void);
@end

@implementation MenuNSWindow
- (BOOL)canBecomeKeyWindow {
  return YES;
}
- (void)windowDidResignKey:(NSNotification*)notification {
  if (self.onResignKey) self.onResignKey();
}
@end

struct MenuWindow::Native {
  MenuNSWindow* window = nil;
};

class MenuWindow::Page : public UiView {
 public:
  explicit Page(MenuWindow* owner)
      : UiView("menu.html", CefSize(kInitialWidth, kInitialHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "size") {
      owner_->OnSize(message->GetInt("width"), message->GetInt("height"));
    } else if (type == "run") {
      owner_->Run(message->GetInt("id"));
    } else if (type == "close") {
      owner_->Close();
    } else {
      return false;
    }
    return true;
  }

 private:
  MenuWindow* owner_;  // Null once the menu has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

void MenuWindow::Show(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run) {
  CEF_REQUIRE_UI_THREAD();
  if (g_open) g_open->Close();
  g_open = new MenuWindow(parent, top_right, std::move(items), std::move(run));
  g_open->Open();
}

MenuWindow::MenuWindow(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run)
    : parent_(parent),
      top_right_(top_right),
      items_(std::move(items)),
      run_(std::move(run)),
      page_(new Page(this)),
      native_(new Native()) {}

MenuWindow::~MenuWindow() {
  page_->Detach();
}

void MenuWindow::Open() {
  // Hidden until the page has laid out its items (OnSize).
  const CefRect bounds(top_right_.x - kInitialWidth, top_right_.y, kInitialWidth, kInitialHeight);
  MenuNSWindow* window = [[MenuNSWindow alloc] initWithContentRect:ToFrame(bounds)
                                                         styleMask:NSWindowStyleMaskBorderless
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO];
  window.releasedWhenClosed = NO;
  window.hasShadow = YES;
  window.delegate = window;
  CefRefPtr<MenuWindow> self(this);
  // A click anywhere else.
  window.onResignKey = ^{
    if (self->shown_) self->Close();
  };
  native_->window = window;
  page_->CreateIn((__bridge CefWindowHandle)window.contentView, CefRect(0, 0, kInitialWidth, kInitialHeight));
}

void MenuWindow::OnConnected() {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const Item& item : items_) {
    CefRefPtr<CefDictionaryValue> entry = CefDictionaryValue::Create();
    if (item.id < 0) {
      entry->SetBool("separator", true);
    } else {
      entry->SetInt("id", item.id);
      entry->SetString("label", item.label);
      entry->SetBool("enabled", item.enabled);
    }
    list->SetDictionary(list->GetSize(), entry);
  }
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "items");
  message->SetList("items", list);
  page_->Send(message);
}

void MenuWindow::OnSize(int width, int height) {
  MenuNSWindow* window = native_->window;
  if (!window || width <= 0 || height <= 0) return;
  [window setFrame:ToFrame(CefRect(top_right_.x - width, top_right_.y, width, height)) display:YES];
  if (shown_) return;
  shown_ = true;
  NSWindow* parent = ((__bridge NSView*)parent_->GetWindowHandle()).window;
  [parent addChildWindow:window ordered:NSWindowAbove];
  [window makeKeyAndOrderFront:nil];
  if (CefRefPtr<CefBrowser> page = page_->browser()) page->GetHost()->SetFocus(true);
}

void MenuWindow::Run(int id) {
  RunCallback run = std::move(run_);
  Close();
  // Once the menu has gone, so the command acts on the browser window.
  if (run) CefPostTask(TID_UI, base::BindOnce([](RunCallback run, int id) { run(id); }, std::move(run), id));
}

void MenuWindow::Close() {
  run_ = nullptr;
  if (MenuNSWindow* window = native_->window) {
    native_->window = nil;
    window.onResignKey = nil;
    window.delegate = nil;
    [window.parentWindow removeChildWindow:window];
    [window orderOut:nil];
    page_->CloseInWindow();  // Its window with it.
  }
  if (g_open.get() == this) g_open = nullptr;
}
