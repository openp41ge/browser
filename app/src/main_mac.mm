// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

// Entry point for the browser process on macOS.

#import <Cocoa/Cocoa.h>

#include <string>

#include "include/cef_application_mac.h"
#include "include/cef_command_line.h"
#include "include/cef_id_mappers.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

#include "browser_manager.h"
#include "explorer_app.h"

namespace {

constexpr char kProductName[] = "openp41ge explorer";

// `--user-data-dir=<path>` if given (tests use a throwaway profile),
// otherwise ~/Library/Application Support/openp41ge explorer.
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
  return std::string(support.UTF8String) + "/" + kProductName;
}

}  // namespace

// Menu actions that need the browser. Chrome commands (IDC_*) run in the
// active page; the item's tag is the command id.
@interface ExplorerMenuTarget : NSObject <NSMenuItemValidation>
- (void)chromeCommand:(NSMenuItem*)sender;
- (void)newWindow:(id)sender;
- (void)closeWindow:(id)sender;
- (void)togglePopout:(id)sender;
@end

@implementation ExplorerMenuTarget

- (void)chromeCommand:(NSMenuItem*)sender {
  if (BrowserManager* manager = BrowserManager::Get()) manager->ExecuteChromeCommand(static_cast<int>(sender.tag));
}

- (void)newWindow:(id)sender {
  if (BrowserManager* manager = BrowserManager::Get()) manager->OpenPageWindow(std::string());
}

- (void)closeWindow:(id)sender {
  if (BrowserManager* manager = BrowserManager::Get()) manager->CloseCurrentWindow();
}

- (void)togglePopout:(id)sender {
  if (BrowserManager* manager = BrowserManager::Get()) manager->TogglePopout();
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
  BrowserManager* manager = BrowserManager::Get();
  if (!manager) return NO;
  if (item.action == @selector(togglePopout:)) {
    item.title = manager->popout()->IsOpen() ? @"Put Back Pop-out" : @"Pop Out Video";
    return manager->popout()->IsOpen() || manager->CurrentPage() != nullptr;
  }
  if (item.action == @selector(chromeCommand:)) {
    CefRefPtr<CefBrowser> page = manager->CurrentPage();
    return page && page->GetHost()->CanExecuteChromeCommand(static_cast<int>(item.tag));
  }
  return YES;
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

// A menu item handled by ExplorerMenuTarget.
NSMenuItem* AddAction(NSMenu* menu,
                      NSString* title,
                      SEL action,
                      NSString* key,
                      NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = AddItem(menu, title, action, key, modifiers);
  item.target = g_menu_target;
  return item;
}

// A menu item that runs a Chrome command (IDC_*) in the active page.
NSMenuItem* AddCommand(NSMenu* menu,
                       NSString* title,
                       const char* command_name,
                       NSString* key,
                       NSEventModifierFlags modifiers = NSEventModifierFlagCommand) {
  NSMenuItem* item = AddAction(menu, title, @selector(chromeCommand:), key, modifiers);
  item.tag = cef_id_for_command_id_name(command_name);
  return item;
}

NSMenu* AddSubmenu(NSMenu* menubar, NSString* title) {
  NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
  [menubar addItemWithTitle:title action:nil keyEquivalent:@""].submenu = menu;
  return menu;
}

// Chrome-style menu bar. Edit menu items use the standard Cocoa actions so
// text fields work; most browser items run a Chrome command in the active
// page. Pages have no tab strip yet, so new tabs are new windows.
NSMenu* BuildMainMenu() {
  g_menu_target = [[ExplorerMenuTarget alloc] init];
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
  AddAction(file, @"New Tab", @selector(newWindow:), @"t");
  AddAction(file, @"New Window", @selector(newWindow:), @"n");
  AddCommand(file, @"Open Location…", "IDC_FOCUS_LOCATION", @"l");
  [file addItem:[NSMenuItem separatorItem]];
  AddAction(file, @"Close Window", @selector(closeWindow:), @"w");
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
  AddAction(window, @"Pop Out Video", @selector(togglePopout:), @"p", kCmdShift);
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
