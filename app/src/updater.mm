// Copyright (c) 2026 Richard Kielty. MIT License.

#include "updater.h"

#include "include/cef_command_line.h"

#if defined(EXPLORER_UPDATES)
#import <Sparkle/Sparkle.h>
#endif

namespace updater {

namespace {

std::string g_available;
std::function<void()> g_changed;

void SetAvailable(std::string version) {
  if (version == g_available) return;
  g_available = std::move(version);
  if (g_changed) g_changed();
}

// --pretend-update-available=<version>: shows that as waiting.
void PretendIfAsked() {
  SetAvailable(CefCommandLine::GetGlobalCommandLine()->GetSwitchValue("pretend-update-available"));
}

}  // namespace

#if defined(EXPLORER_UPDATES)
}  // namespace updater

// Shows updates found by the daily check gently, in the browser's own UI
// (Sparkle's "gentle reminders"), instead of Sparkle's window popping up:
// the window comes when the user asks for it (ShowUpdate).
@interface ExplorerUpdateReminders : NSObject <SPUStandardUserDriverDelegate>
@end

@implementation ExplorerUpdateReminders

- (BOOL)supportsGentleScheduledUpdateReminders {
  return YES;
}

- (BOOL)standardUserDriverShouldHandleShowingScheduledUpdate:(SUAppcastItem*)update
                                         andInImmediateFocus:(BOOL)immediateFocus {
  return NO;
}

- (void)standardUserDriverWillHandleShowingUpdate:(BOOL)handleShowingUpdate
                                        forUpdate:(SUAppcastItem*)update
                                            state:(SPUUserUpdateState*)state {
  if (!handleShowingUpdate) updater::SetAvailable(update.displayVersionString.UTF8String);
}

// Installed, skipped or put off: the reminder goes (a put-off update comes
// back with a later check).
- (void)standardUserDriverWillFinishUpdateSession {
  updater::SetAvailable(std::string());
}

@end

namespace updater {

namespace {

SPUStandardUpdaterController* g_controller = nil;
ExplorerUpdateReminders* g_reminders = nil;

}  // namespace

void Start() {
  PretendIfAsked();
  if (CefCommandLine::GetGlobalCommandLine()->HasSwitch("disable-updates")) return;
  g_reminders = [[ExplorerUpdateReminders alloc] init];
  g_controller = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
                                                               updaterDelegate:nil
                                                            userDriverDelegate:g_reminders];
}

NSMenuItem* MenuItem() {
  if (!g_controller) return nil;
  NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Check for Updates…"
                                                action:@selector(checkForUpdates:)
                                         keyEquivalent:@""];
  item.target = g_controller;
  return item;
}

void ShowUpdate() {
  // Brings the update found into focus: Sparkle's window for it.
  [g_controller.updater checkForUpdates];
}

#else

void Start() {
  PretendIfAsked();
}

NSMenuItem* MenuItem() {
  return nil;
}

void ShowUpdate() {}

#endif

std::string AvailableVersion() {
  return g_available;
}

void SetObserver(std::function<void()> changed) {
  g_changed = std::move(changed);
}

}  // namespace updater
