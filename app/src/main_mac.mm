// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

// Entry point for the browser process on macOS.

#import <Cocoa/Cocoa.h>

#include <string>

#include "include/cef_application_mac.h"
#include "include/cef_id_mappers.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

#include "explorer_app.h"
#include "explorer_handler.h"

namespace {

constexpr char kProductName[] = "openp41ge explorer";

// ~/Library/Application Support/openp41ge explorer
std::string AppDataDir() {
  NSString* support = NSSearchPathForDirectoriesInDomains(
                          NSApplicationSupportDirectory, NSUserDomainMask, YES)
                          .firstObject;
  return std::string(support.UTF8String) + "/" + kProductName;
}

NSMenuItem* AddItem(NSMenu* menu,
                    NSString* title,
                    SEL action,
                    NSString* key,
                    NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = [menu addItemWithTitle:title action:action keyEquivalent:key];
  item.keyEquivalentModifierMask = modifiers;
  return item;
}

// A menu item that runs a Chrome command (IDC_*) in the active browser
// window. Chrome also looks up keyboard shortcuts in the main menu, which is
// what makes Cmd+T and friends work while a web page has focus.
NSMenuItem* AddCommand(NSMenu* menu,
                       NSString* title,
                       const char* command_name,
                       NSString* key,
                       NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = AddItem(menu, title, @selector(commandDispatch:), key, modifiers);
  item.tag = cef_id_for_command_id_name(command_name);
  return item;
}

NSMenu* AddSubmenu(NSMenu* menubar, NSString* title) {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
  [menubar addItemWithTitle:title action:nil keyEquivalent:@""].submenu = menu;
  return menu;
}

// Chrome-style menu bar. Edit menu items use the standard Cocoa actions so
// text fields work; everything browser-related dispatches a Chrome command.
NSMenu* BuildMainMenu() {
  constexpr auto kCmdShift = NSEventModifierFlagCommand | NSEventModifierFlagShift;
  constexpr auto kCmdOpt = NSEventModifierFlagCommand | NSEventModifierFlagOption;
  constexpr auto kCmdCtrl = NSEventModifierFlagCommand | NSEventModifierFlagControl;

  NSString* name = @(kProductName);
  NSMenu* menubar = [[NSMenu alloc] init];

  NSMenu* app = AddSubmenu(menubar, name);
  AddCommand(app, @"Settings…", "IDC_OPTIONS", @",");
  [app addItem:[NSMenuItem separatorItem]];
  AddItem(app, [@"Hide " stringByAppendingString:name], @selector(hide:), @"h");
  AddItem(app, @"Hide Others", @selector(hideOtherApplications:), @"h", kCmdOpt);
  AddItem(app, @"Show All", @selector(unhideAllApplications:), @"", 0);
  [app addItem:[NSMenuItem separatorItem]];
  AddItem(app, [@"Quit " stringByAppendingString:name], @selector(terminate:), @"q");

  NSMenu* file = AddSubmenu(menubar, @"File");
  AddCommand(file, @"New Tab", "IDC_NEW_TAB", @"t");
  AddCommand(file, @"New Window", "IDC_NEW_WINDOW", @"n");
  AddCommand(file, @"New Incognito Window", "IDC_NEW_INCOGNITO_WINDOW", @"n", kCmdShift);
  AddCommand(file, @"Reopen Closed Tab", "IDC_RESTORE_TAB", @"t", kCmdShift);
  AddCommand(file, @"Open Location…", "IDC_FOCUS_LOCATION", @"l");
  [file addItem:[NSMenuItem separatorItem]];
  AddCommand(file, @"Close Window", "IDC_CLOSE_WINDOW", @"w", kCmdShift);
  AddCommand(file, @"Close Tab", "IDC_CLOSE_TAB", @"w");
  [file addItem:[NSMenuItem separatorItem]];
  AddCommand(file, @"Print…", "IDC_PRINT", @"p");

  NSMenu* edit = AddSubmenu(menubar, @"Edit");
  AddItem(edit, @"Undo", @selector(undo:), @"z");
  AddItem(edit, @"Redo", @selector(redo:), @"z", kCmdShift);
  [edit addItem:[NSMenuItem separatorItem]];
  AddItem(edit, @"Cut", @selector(cut:), @"x");
  AddItem(edit, @"Copy", @selector(copy:), @"c");
  AddItem(edit, @"Paste", @selector(paste:), @"v");
  AddItem(edit, @"Select All", @selector(selectAll:), @"a");
  [edit addItem:[NSMenuItem separatorItem]];
  AddCommand(edit, @"Find…", "IDC_FIND", @"f");
  AddCommand(edit, @"Find Next", "IDC_FIND_NEXT", @"g");
  AddCommand(edit, @"Find Previous", "IDC_FIND_PREVIOUS", @"g", kCmdShift);

  NSMenu* view = AddSubmenu(menubar, @"View");
  AddCommand(view, @"Reload This Page", "IDC_RELOAD", @"r");
  AddCommand(view, @"Force Reload This Page", "IDC_RELOAD_BYPASSING_CACHE", @"r", kCmdShift);
  [view addItem:[NSMenuItem separatorItem]];
  AddCommand(view, @"Enter Full Screen", "IDC_FULLSCREEN", @"f", kCmdCtrl);
  AddCommand(view, @"Actual Size", "IDC_ZOOM_NORMAL", @"0");
  AddCommand(view, @"Zoom In", "IDC_ZOOM_PLUS", @"=");
  AddCommand(view, @"Zoom Out", "IDC_ZOOM_MINUS", @"-");
  [view addItem:[NSMenuItem separatorItem]];
  AddCommand(view, @"Developer Tools", "IDC_DEV_TOOLS", @"i", kCmdOpt);
  AddCommand(view, @"JavaScript Console", "IDC_DEV_TOOLS_CONSOLE", @"j", kCmdOpt);
  AddCommand(view, @"View Source", "IDC_VIEW_SOURCE", @"u", kCmdOpt);

  NSMenu* history = AddSubmenu(menubar, @"History");
  AddCommand(history, @"Back", "IDC_BACK", @"[");
  AddCommand(history, @"Forward", "IDC_FORWARD", @"]");
  [history addItem:[NSMenuItem separatorItem]];
  AddCommand(history, @"Show Full History", "IDC_SHOW_HISTORY", @"y");

  NSMenu* bookmarks = AddSubmenu(menubar, @"Bookmarks");
  AddCommand(bookmarks, @"Bookmark This Tab…", "IDC_BOOKMARK_THIS_TAB", @"d");
  AddCommand(bookmarks, @"Bookmark Manager", "IDC_SHOW_BOOKMARK_MANAGER", @"b", kCmdOpt);

  NSMenu* window = AddSubmenu(menubar, @"Window");
  AddItem(window, @"Minimize", @selector(performMiniaturize:), @"m");
  AddItem(window, @"Zoom", @selector(performZoom:), @"", 0);
  [window addItem:[NSMenuItem separatorItem]];
  AddCommand(window, @"Select Next Tab", "IDC_SELECT_NEXT_TAB", @"}", kCmdShift);
  AddCommand(window, @"Select Previous Tab", "IDC_SELECT_PREVIOUS_TAB", @"{", kCmdShift);
  [window addItem:[NSMenuItem separatorItem]];
  AddCommand(window, @"Downloads", "IDC_SHOW_DOWNLOADS", @"j", kCmdShift);
  AddCommand(window, @"Extensions", "IDC_MANAGE_EXTENSIONS", @"", 0);
  AddCommand(window, @"Task Manager", "IDC_TASK_MANAGER", @"", 0);
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
// closes all browsers instead of calling exit(). When the last browser
// closes, ExplorerHandler ends the message loop and main() returns.
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
  ExplorerHandler* handler = ExplorerHandler::GetInstance();
  if (handler && !handler->IsClosing()) {
    handler->CloseAllBrowsers(false);
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
    const std::string data_dir = AppDataDir();
    CefString(&settings.root_cache_path) = data_dir;
    CefString(&settings.cache_path) = data_dir + "/Default";

    CefRefPtr<ExplorerApp> app(new ExplorerApp);
    // Returns false if another instance is already running (it gets focused
    // instead) or initialization fails.
    if (!CefInitialize(main_args, settings, app.get(), nullptr)) {
      return CefGetExitCode();
    }

    ExplorerAppDelegate* delegate = [[ExplorerAppDelegate alloc] init];
    NSApp.delegate = delegate;
    [delegate performSelectorOnMainThread:@selector(createApplication:)
                               withObject:nil
                            waitUntilDone:NO];

    CefRunMessageLoop();  // Blocks until the last browser closes.
    CefShutdown();
    delegate = nil;
  }
  return 0;
}
