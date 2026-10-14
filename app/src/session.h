// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_SESSION_H_
#define OPENP41GE_EXPLORER_SESSION_H_

#include <string>
#include <vector>

#include "window_layout.h"

// The windows open (not private ones), kept in the profile as JSON
// (<profile>/Session.json) so the next start brings them back: written a
// moment after they change, and as the app quits, before its windows close.
// So it holds what was open when the app quit, was quit by an update, or
// was stopped (force quit, a crash); and nothing if the last window was
// closed. UI thread.
namespace session {

// `folder`: the profile's folder. Back to front, as they were stacked.
std::vector<WindowLayout> Read(const std::string& folder);
// Written on the file thread, or before returning if `now` (as the app
// quits, when work posted elsewhere may not run).
void Write(const std::string& folder, const std::vector<WindowLayout>& windows, bool now);

}  // namespace session

#endif  // OPENP41GE_EXPLORER_SESSION_H_
