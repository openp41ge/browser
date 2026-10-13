// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_UI_LIVE_RELOAD_H_
#define OPENP41GE_EXPLORER_UI_UI_LIVE_RELOAD_H_

#include <functional>
#include <string>

// A development build's UI comes straight from the checkout it was built
// from: openp41ge://ui/ and openp41ge://start/ are served from its app/ui
// (when it's there; otherwise from the bundle, as a release build's are),
// and the UI's views and start pages reload when a file there changes. So
// an edit to the UI shows a moment after it's saved, with no build or
// restart.
namespace ui_live_reload {

// The checkout's app/ui, in a development build if it's there; else empty.
std::string SourceDir();

// Watches SourceDir() (if there is one): `changed` runs on the UI thread
// once files there change (a burst of changes, such as a save, runs it
// once).
void Watch(std::function<void()> changed);

}  // namespace ui_live_reload

#endif  // OPENP41GE_EXPLORER_UI_UI_LIVE_RELOAD_H_
