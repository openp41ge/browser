// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_DRAG_IMAGE_H_
#define OPENP41GE_EXPLORER_TAB_DRAG_IMAGE_H_

#include <memory>
#include <string>

#include "include/internal/cef_types_wrappers.h"

// What follows the pointer while a tab is dragged: a small card of the tab
// (its address) over a snapshot of its page, floating above every window so
// it can be carried to another window or onto the desktop. A native panel of
// its own that ignores the mouse (the tab bar the drag started in keeps it).
class TabDragImage {
 public:
  explicit TabDragImage(const std::string& title);
  ~TabDragImage();

  // The page's snapshot (an encoded image, e.g. JPEG), once it arrives.
  void SetSnapshot(const std::string& encoded);
  // Puts the card's tab under the pointer at `screen` (CEF screen
  // coordinates).
  void MoveTo(const CefPoint& screen);

  // Where the pointer sits within the card: on its tab, a little in.
  static constexpr int kGrabX = 48;
  static constexpr int kGrabY = 17;

 private:
  struct Native;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_TAB_DRAG_IMAGE_H_
