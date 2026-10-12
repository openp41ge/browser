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
// ignores the mouse (as DropPreview).
class FocusBar {
 public:
  static constexpr int kThickness = 3;

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
