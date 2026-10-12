// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BORDERLESS_H_
#define OPENP41GE_EXPLORER_BORDERLESS_H_

#include "include/views/cef_window.h"

// Makes a frameless CefWindow (a menu, the suggestions) a plain borderless
// one. CEF creates frameless windows as titled windows with the title bar
// hidden, which macOS draws with rounded corners and an outline; the
// browser's UI is square, and its pages draw their own border.
void MakeBorderless(CefRefPtr<CefWindow> window);

#endif  // OPENP41GE_EXPLORER_BORDERLESS_H_
