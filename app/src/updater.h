// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UPDATER_H_
#define OPENP41GE_EXPLORER_UPDATER_H_

#import <Cocoa/Cocoa.h>

// Updates, in release builds (Sparkle): the app checks its feed daily and
// installs what it finds when it quits. Development builds have none.
namespace updater {

// Starts the updater, unless there's none or the command line has
// --disable-updates (the tests: a test run mustn't update the app).
void Start();

// "Check for Updates…" for the app menu; nil without a running updater.
NSMenuItem* MenuItem();

}  // namespace updater

#endif  // OPENP41GE_EXPLORER_UPDATER_H_
