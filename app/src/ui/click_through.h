// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_CLICK_THROUGH_H_
#define OPENP41GE_EXPLORER_UI_CLICK_THROUGH_H_

#include <functional>

#include "include/internal/cef_mac.h"
#include "include/internal/cef_types_wrappers.h"

// The browser's own UI takes a click while its window isn't the key one, as
// a Mac app's controls do: the click brings the window forward and presses
// the button too. Web pages keep Chromium's way.
//
// AppKit asks the view under the click (acceptsFirstMouse:), here Chromium's
// view for a page (RenderWidgetHostViewCocoa), which can refuse: then the
// click only brings the window forward. It's replaced, once, by one that
// accepts a click on the UI and otherwise asks Chromium's. (Also for
// BridgedContentView, Chromium's view for a whole CEF window, in case it's
// the one under the click.)
namespace click_through {

// Whether `point` (screen coordinates from the top left, in points) in
// `window` (an NSWindow) is on a UI page.
using UiAt = std::function<bool(void* window, const CefPoint& point)>;

// Starts taking first clicks where `ui_at` says. Once; later calls do nothing.
void Install(UiAt ui_at);

// `view` (a UI page's own view, in a window of our own) and the views in it
// take first clicks. Held weakly: nothing to undo when it goes.
void Allow(CefWindowHandle view);

}  // namespace click_through

#endif  // OPENP41GE_EXPLORER_UI_CLICK_THROUGH_H_
