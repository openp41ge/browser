// Copyright (c) 2026 Richard Kielty. MIT License.

#include "updater.h"

#if defined(EXPLORER_UPDATES)
#import <Sparkle/Sparkle.h>

#include "include/cef_command_line.h"
#endif

namespace updater {

#if defined(EXPLORER_UPDATES)

namespace {
SPUStandardUpdaterController* g_controller = nil;
}  // namespace

void Start() {
  if (CefCommandLine::GetGlobalCommandLine()->HasSwitch("disable-updates")) return;
  g_controller = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
                                                               updaterDelegate:nil
                                                            userDriverDelegate:nil];
}

NSMenuItem* MenuItem() {
  if (!g_controller) return nil;
  NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"Check for Updates…"
                                                action:@selector(checkForUpdates:)
                                         keyEquivalent:@""];
  item.target = g_controller;
  return item;
}

#else

void Start() {}

NSMenuItem* MenuItem() {
  return nil;
}

#endif

}  // namespace updater
