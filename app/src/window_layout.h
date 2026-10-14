// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_WINDOW_LAYOUT_H_
#define OPENP41GE_EXPLORER_WINDOW_LAYOUT_H_

#include <string>
#include <vector>

#include "include/internal/cef_types_wrappers.h"

// A window as it was, to bring back: when it closed (Reopen Closed Window),
// or when the app last quit (the session, session.h). Its frame, and each
// pane's share of the width, its tabs, and which one was active; and whether
// its tab bars showed previews.
struct WindowLayout {
  // What a tab shows without its page loaded.
  struct SavedTab {
    std::string url;
    std::string title;
    std::string favicon;
    std::string preview;  // Its picture's token (tab_previews.h), if any.
  };
  struct PaneTabs {
    std::vector<SavedTab> tabs;
    int active = 0;
    int weight = 1000;  // As Pane::weight.
  };
  CefRect bounds;
  std::vector<PaneTabs> panes;
  int active_pane = 0;
  bool previews = false;  // Its tab bars showing previews.
};

#endif  // OPENP41GE_EXPLORER_WINDOW_LAYOUT_H_
