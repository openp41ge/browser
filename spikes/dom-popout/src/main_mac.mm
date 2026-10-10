// Copyright (c) 2026 Richard Kielty. MIT License.
// App setup adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

// DOM pop-out spike: one Alloy page in a window. Cmd+Shift+P moves the
// element matching --selector (default: YouTube's player) into its own
// window, as real DOM in the same page; again (or closing it) moves it back.
//
//   --start-url=<url>      page to open (default: a YouTube video). Not --url:
//                          Chromium's startup code cancels Alloy navigations
//                          when that switch is present.
//   --selector=<css>       element to pop out
//   --user-data-dir=<dir>  profile directory

#import <Cocoa/Cocoa.h>

#include <functional>
#include <string>

#include "include/cef_app.h"
#include "include/cef_application_mac.h"
#include "include/cef_command_line.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

#include "spike_client.h"

namespace {

constexpr char kDefaultUrl[] = "https://www.youtube.com/watch?v=aqz-KE-bpKQ";
constexpr char kDefaultSelector[] = "#movie_player";

std::string SwitchOr(CefRefPtr<CefCommandLine> command_line,
                     const char* name,
                     const std::string& fallback) {
  const std::string value = command_line->GetSwitchValue(name);
  return value.empty() ? fallback : value;
}

std::string DefaultDataDir() {
  NSString* support = NSSearchPathForDirectoriesInDomains(
                          NSApplicationSupportDirectory, NSUserDomainMask, YES)
                          .firstObject;
  return std::string(support.UTF8String) + "/openp41ge dom popout spike";
}

class SpikeApp : public CefApp, public CefBrowserProcessHandler {
 public:
  explicit SpikeApp(std::function<void()> on_ready) : on_ready_(std::move(on_ready)) {}

  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }

  // Keep the page running at full speed while its element is in another
  // window, even if the main window is hidden behind others or minimized.
  void OnBeforeCommandLineProcessing(const CefString& process_type,
                                     CefRefPtr<CefCommandLine> command_line) override {
    if (process_type.empty()) {
      command_line->AppendSwitch("disable-background-timer-throttling");
      command_line->AppendSwitch("disable-renderer-backgrounding");
      command_line->AppendSwitch("disable-backgrounding-occluded-windows");
      // Spike profiles are throwaway: don't ask for the macOS Keychain.
      command_line->AppendSwitch("use-mock-keychain");
    }
  }

  void OnContextInitialized() override { on_ready_(); }

 private:
  std::function<void()> on_ready_;
  IMPLEMENT_REFCOUNTING(SpikeApp);
};

}  // namespace

// Menu target for the pop-out toggle.
@interface PopoutAction : NSObject
@property(nonatomic) CefRefPtr<SpikeClient> client;
- (void)toggle:(id)sender;
@end

@implementation PopoutAction
- (void)toggle:(id)sender {
  if (_client) _client->TogglePopout();
}
@end

@interface SpikeApplication : NSApplication <CefAppProtocol> {
 @private
  BOOL handlingSendEvent_;
}
@property(nonatomic) CefRefPtr<SpikeClient> client;
@end

@implementation SpikeApplication

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

// Close the browsers and let CEF leave its message loop (see cefsimple).
- (void)terminate:(id)sender {
  if (_client) {
    _client->CloseAll();
  } else {
    CefQuitMessageLoop();
  }
}

@end

namespace {

NSMenu* BuildMenu(PopoutAction* popout) {
  NSMenu* menubar = [[NSMenu alloc] init];

  NSMenu* app = [[NSMenu alloc] init];
  [app addItemWithTitle:@"Quit DOM Pop-out Spike" action:@selector(terminate:) keyEquivalent:@"q"];
  [menubar addItemWithTitle:@"" action:nil keyEquivalent:@""].submenu = app;

  NSMenu* edit = [[NSMenu alloc] initWithTitle:@"Edit"];
  [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
  [edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
  [edit addItem:[NSMenuItem separatorItem]];
  [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  [menubar addItemWithTitle:@"Edit" action:nil keyEquivalent:@""].submenu = edit;

  NSMenu* spike = [[NSMenu alloc] initWithTitle:@"Pop-out"];
  NSMenuItem* toggle = [spike addItemWithTitle:@"Toggle Pop-out"
                                        action:@selector(toggle:)
                                 keyEquivalent:@"P"];
  toggle.target = popout;
  [menubar addItemWithTitle:@"Pop-out" action:nil keyEquivalent:@""].submenu = spike;

  NSMenu* window = [[NSMenu alloc] initWithTitle:@"Window"];
  [window addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
  [menubar addItemWithTitle:@"Window" action:nil keyEquivalent:@""].submenu = window;
  NSApp.windowsMenu = window;

  return menubar;
}

}  // namespace

int main(int argc, char* argv[]) {
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInMain()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);

  @autoreleasepool {
    [SpikeApplication sharedApplication];
    CHECK([NSApp isKindOfClass:[SpikeApplication class]]);

    CefRefPtr<CefCommandLine> command_line = CefCommandLine::CreateCommandLine();
    command_line->InitFromArgv(argc, argv);
    const std::string url = SwitchOr(command_line, "start-url", kDefaultUrl);
    const std::string selector = SwitchOr(command_line, "selector", kDefaultSelector);

    CefSettings settings;
#if !defined(CEF_USE_SANDBOX)
    settings.no_sandbox = true;
#endif
    const std::string data_dir = SwitchOr(command_line, "user-data-dir", DefaultDataDir());
    CefString(&settings.root_cache_path) = data_dir;
    CefString(&settings.cache_path) = data_dir + "/Default";

    PopoutAction* popout = [[PopoutAction alloc] init];
    CefRefPtr<SpikeApp> app(new SpikeApp([url, selector, popout] {
      NSWindow* window = [[NSWindow alloc]
          initWithContentRect:NSMakeRect(0, 0, 1280, 800)
                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
                      backing:NSBackingStoreBuffered
                        defer:NO];
      window.releasedWhenClosed = NO;
      [window center];
      NSView* content = window.contentView;

      CefRefPtr<SpikeClient> client(new SpikeClient(window, content, selector));
      popout.client = client;
      static_cast<SpikeApplication*>(NSApp).client = client;
      NSApp.mainMenu = BuildMenu(popout);

      client->CreatePage(url);

      [window makeKeyAndOrderFront:nil];
    }));

    if (!CefInitialize(main_args, settings, app.get(), nullptr)) {
      return CefGetExitCode();
    }

    CefRunMessageLoop();
    CefShutdown();
    static_cast<SpikeApplication*>(NSApp).client = nullptr;
    popout.client = nullptr;
  }
  return 0;
}
