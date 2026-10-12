// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

// Entry point for the browser process on macOS.

#import <Cocoa/Cocoa.h>
#include <dispatch/dispatch.h>

#include <csignal>
#include <string>

#include "include/cef_application_mac.h"
#include "include/cef_command_line.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

#include "browser_manager.h"
#include "explorer_app.h"

namespace {

constexpr char kProductName[] = "openp41ge explorer";

// `--user-data-dir=<path>` if given (tests use a throwaway profile),
// otherwise ~/Library/Application Support/openp41ge explorer (a development
// build: "openp41ge explorer development", apart from the release's).
std::string AppDataDir(int argc, char* argv[]) {
  CefRefPtr<CefCommandLine> command_line = CefCommandLine::CreateCommandLine();
  command_line->InitFromArgv(argc, argv);
  const std::string override_dir = command_line->GetSwitchValue("user-data-dir");
  if (!override_dir.empty()) {
    return override_dir;
  }
  NSString* support = NSSearchPathForDirectoriesInDomains(
                          NSApplicationSupportDirectory, NSUserDomainMask, YES)
                          .firstObject;
#if defined(EXPLORER_DEV_BUILD)
  return std::string(support.UTF8String) + "/" + kProductName + " development";
#else
  return std::string(support.UTF8String) + "/" + kProductName;
#endif
}

}  // namespace

// Menu items that act on the browser; the item's tag is the
// BrowserManager::Command.
@interface ExplorerMenuTarget : NSObject <NSMenuItemValidation>
- (void)command:(NSMenuItem*)sender;
@end

@implementation ExplorerMenuTarget

- (void)command:(NSMenuItem*)sender {
  BrowserManager* manager = BrowserManager::Get();
  if (!manager) return;
  const auto command = static_cast<BrowserManager::Command>(sender.tag);
  // Closing while the pop-out has the keyboard closes the pop-out.
  if ((command == BrowserManager::Command::kCloseTab || command == BrowserManager::Command::kCloseWindow) &&
      [NSApp.keyWindow isKindOfClass:NSClassFromString(@"PopoutWindow")]) {
    manager->popout()->Close();
    return;
  }
  manager->Run(command);
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
  BrowserManager* manager = BrowserManager::Get();
  if (!manager) return NO;
  const auto command = static_cast<BrowserManager::Command>(item.tag);
  if (command == BrowserManager::Command::kTogglePopout) {
    item.title = manager->popout()->IsOpen() ? @"Put Back Pop-out" : @"Pop Out Video";
  }
  return manager->CanRun(command);
}

@end

namespace {

ExplorerMenuTarget* g_menu_target = nil;

NSMenuItem* AddItem(NSMenu* menu,
                    NSString* title,
                    SEL action,
                    NSString* key,
                    NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = [menu addItemWithTitle:title action:action keyEquivalent:key];
  item.keyEquivalentModifierMask = modifiers;
  return item;
}

// A menu item that runs a browser command.
NSMenuItem* AddCommand(NSMenu* menu,
                       NSString* title,
                       BrowserManager::Command command,
                       NSString* key,
                       NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = AddItem(menu, title, @selector(command:), key, modifiers);
  item.target = g_menu_target;
  item.tag = static_cast<NSInteger>(command);
  return item;
}

NSMenu* AddSubmenu(NSMenu* menubar, NSString* title) {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
  [menubar addItemWithTitle:title action:nil keyEquivalent:@""].submenu = menu;
  return menu;
}

// The menu bar. Edit items use the standard Cocoa actions so text fields
// work; browser items run a BrowserManager command.
NSMenu* BuildMainMenu() {
  using Command = BrowserManager::Command;
  g_menu_target = [[ExplorerMenuTarget alloc] init];
  constexpr auto kCmdShift = NSEventModifierFlagCommand | NSEventModifierFlagShift;
  constexpr auto kCmdOpt = NSEventModifierFlagCommand | NSEventModifierFlagOption;
  constexpr auto kCmdCtrl = NSEventModifierFlagCommand | NSEventModifierFlagControl;

  // As the Dock shows it (Info.plist: "Chromium" for a development build).
  NSString* name = NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @(kProductName);
  NSMenu* menubar = [[NSMenu alloc] init];

  NSMenu* app = AddSubmenu(menubar, name);
  AddItem(app, [@"Hide " stringByAppendingString:name], @selector(hide:), @"h");
  AddItem(app, @"Hide Others", @selector(hideOtherApplications:), @"h", kCmdOpt);
  AddItem(app, @"Show All", @selector(unhideAllApplications:), @"", 0);
  [app addItem:[NSMenuItem separatorItem]];
  AddItem(app, [@"Quit " stringByAppendingString:name], @selector(terminate:), @"q");

  NSMenu* file = AddSubmenu(menubar, @"File");
  AddCommand(file, @"New Tab", Command::kNewTab, @"t");
  AddCommand(file, @"New Window", Command::kNewWindow, @"n");
  AddCommand(file, @"New Private Window", Command::kNewPrivateWindow, @"n", kCmdShift);
  [file addItem:[NSMenuItem separatorItem]];
  AddCommand(file, @"Close Tab", Command::kCloseTab, @"w");
  AddCommand(file, @"Close Window", Command::kCloseWindow, @"w", kCmdShift);
  [file addItem:[NSMenuItem separatorItem]];
  AddCommand(file, @"Print…", Command::kPrint, @"p");

  NSMenu* edit = AddSubmenu(menubar, @"Edit");
  AddItem(edit, @"Undo", @selector(undo:), @"z");
  AddItem(edit, @"Redo", @selector(redo:), @"z", kCmdShift);
  [edit addItem:[NSMenuItem separatorItem]];
  AddItem(edit, @"Cut", @selector(cut:), @"x");
  AddItem(edit, @"Copy", @selector(copy:), @"c");
  AddItem(edit, @"Paste", @selector(paste:), @"v");
  AddItem(edit, @"Select All", @selector(selectAll:), @"a");

  NSMenu* view = AddSubmenu(menubar, @"View");
  AddCommand(view, @"Reload This Page", Command::kReload, @"r");
  AddCommand(view, @"Force Reload This Page", Command::kReloadIgnoringCache, @"r", kCmdShift);
  [view addItem:[NSMenuItem separatorItem]];
  AddItem(view, @"Enter Full Screen", @selector(toggleFullScreen:), @"f", kCmdCtrl);
  AddCommand(view, @"Actual Size", Command::kZoomReset, @"0");
  AddCommand(view, @"Zoom In", Command::kZoomIn, @"=");
  AddCommand(view, @"Zoom Out", Command::kZoomOut, @"-");
  [view addItem:[NSMenuItem separatorItem]];
  AddCommand(view, @"Developer Tools", Command::kDevTools, @"i", kCmdOpt);
  AddCommand(view, @"View Source", Command::kViewSource, @"u", kCmdOpt);

  NSMenu* history = AddSubmenu(menubar, @"History");
  AddCommand(history, @"Back", Command::kBack, @"[");
  AddCommand(history, @"Forward", Command::kForward, @"]");

  NSMenu* window = AddSubmenu(menubar, @"Window");
  AddItem(window, @"Minimize", @selector(performMiniaturize:), @"m");
  AddItem(window, @"Zoom", @selector(performZoom:), @"", 0);
  [window addItem:[NSMenuItem separatorItem]];
  AddCommand(window, @"Show Next Tab", Command::kNextTab, @"]", kCmdShift);
  AddCommand(window, @"Show Previous Tab", Command::kPreviousTab, @"[", kCmdShift);
  [window addItem:[NSMenuItem separatorItem]];
  AddCommand(window, @"Pop Out Video", Command::kTogglePopout, @"p", kCmdShift);
  [window addItem:[NSMenuItem separatorItem]];
  AddItem(window, @"Bring All to Front", @selector(arrangeInFront:), @"", 0);
  NSApp.windowsMenu = window;

  return menubar;
}

}  // namespace

@interface ExplorerAppDelegate : NSObject <NSApplicationDelegate>
- (void)createApplication:(id)object;
- (void)tryToTerminateApplication:(NSApplication*)app;
@end

// CEF requires the NSApplication subclass to implement CefAppProtocol.
@interface ExplorerApplication : NSApplication <CefAppProtocol> {
 @private
  BOOL handlingSendEvent_;
}
@end

@implementation ExplorerApplication

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

// Chromium needs to leave the run loop to shut down cleanly, so quitting
// closes all windows instead of calling exit(). When the last one closes,
// BrowserManager ends the message loop and main() returns.
- (void)terminate:(id)sender {
  auto* delegate = static_cast<ExplorerAppDelegate*>([NSApp delegate]);
  [delegate tryToTerminateApplication:self];
}

@end

@implementation ExplorerAppDelegate

- (void)createApplication:(id)object {
  NSApp.mainMenu = BuildMainMenu();
  [[NSApplication sharedApplication] setDelegate:self];
}

- (void)tryToTerminateApplication:(NSApplication*)app {
  BrowserManager* manager = BrowserManager::Get();
  if (!manager) {
    CefQuitMessageLoop();
  } else if (!manager->IsClosing()) {
    manager->CloseAll();
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
  return NSTerminateNow;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)app {
  return YES;
}

@end

int main(int argc, char* argv[]) {
  // The macOS sandbox requires loading the CEF framework at runtime.
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInMain()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);

  @autoreleasepool {
    [ExplorerApplication sharedApplication];
    CHECK([NSApp isKindOfClass:[ExplorerApplication class]]);

    CefSettings settings;
#if !defined(CEF_USE_SANDBOX)
    settings.no_sandbox = true;
#endif
    // Persistent profile: logins, cookies and history survive restarts.
    const std::string data_dir = AppDataDir(argc, argv);
    CefString(&settings.root_cache_path) = data_dir;
    CefString(&settings.cache_path) = data_dir + "/Default";

    CefRefPtr<ExplorerApp> app(new ExplorerApp);
    // Returns false if another instance is already running (it gets focused
    // instead) or initialization fails.
    if (!CefInitialize(main_args, settings, app.get(), nullptr)) {
      return CefGetExitCode();
    }

    // SIGTERM (`kill`, the tests): quit as the Quit menu item does, so the
    // app closes its windows and keeps what it must before shutting down
    // (left to Chromium, the process would end without returning here).
    signal(SIGTERM, SIG_IGN);
    dispatch_source_t sigterm =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(sigterm, ^{
      [NSApp terminate:nil];
    });
    dispatch_resume(sigterm);

    ExplorerAppDelegate* delegate = [[ExplorerAppDelegate alloc] init];
    NSApp.delegate = delegate;
    [delegate performSelectorOnMainThread:@selector(createApplication:)
                               withObject:nil
                            waitUntilDone:NO];

    CefRunMessageLoop();  // Blocks until the last browser closes.
    if (BrowserManager* manager = BrowserManager::Get()) manager->OnMessageLoopEnded();
    CefShutdown();
    delegate = nil;
  }
  return 0;
}
