// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UPDATER_H_
#define OPENP41GE_EXPLORER_UPDATER_H_

#import <Cocoa/Cocoa.h>

#include <functional>
#include <string>

// Updates, in release builds (Sparkle): the app checks its feed daily, and
// an update it finds waits for the user to accept it, as Chrome's do. The
// top bar's menu button says "Update available" and its menu starts with
// the update; choosing it opens Sparkle's window for it (what's new,
// Install Update). Nothing installs without that. Development builds have
// no updater.
namespace updater {

// Starts the updater, unless there's none or the command line has
// --disable-updates (the tests: a test run mustn't update the app).
void Start();

// "Check for Updates…" for the app menu; nil without a running updater.
NSMenuItem* MenuItem();

// The version of an update that's waiting for the user, or empty. (A
// development build has none, unless it's run with
// --pretend-update-available=<version>, for the tests and UI work.)
std::string AvailableVersion();
// Runs on the UI thread whenever that changes.
void SetObserver(std::function<void()> changed);
// The user wants the update: Sparkle's window for it.
void ShowUpdate();

}  // namespace updater

#endif  // OPENP41GE_EXPLORER_UPDATER_H_
