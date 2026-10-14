// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_FOCUS_BAR_H_
#define OPENP41GE_EXPLORER_FOCUS_BAR_H_

#include <memory>

#include "include/internal/cef_types_wrappers.h"
#include "include/views/cef_window.h"

// The focused tab's mark: a rounded blue bar floating across the tab's top
// edge, half on the tab and half on the top bar above it. The tab bar and
// the top bar are separate web views, neither of which can draw outside
// itself, so it's a transparent panel of its own over the window that
// ignores the mouse (as DropPreview): clicks go to what's under it. With
// the pointer over it (watched as it moves), it grows up and down into a
// pill that says "FOCUSED".
class FocusBar {
 public:
  static constexpr int kThickness = 3;
  // Its height grown (even: its middle stays on the edge's whole point).
  static constexpr int kGrownThickness = 16;
  // How far it grows out to each side (a 50pt bar is a 60pt pill).
  static constexpr int kGrownOutset = 5;

  explicit FocusBar(CefRefPtr<CefWindow> parent);
  ~FocusBar();

  // Shows it centred on the horizontal edge at `y` from `x`, `width` long
  // (CEF screen coordinates).
  void Show(int x, int y, int width);
  void Hide();

 private:
  struct Native;

  CefRefPtr<CefWindow> parent_;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_FOCUS_BAR_H_
