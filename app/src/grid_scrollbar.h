// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_GRID_SCROLLBAR_H_
#define OPENP41GE_EXPLORER_GRID_SCROLLBAR_H_

#include <functional>
#include <memory>

#include "include/views/cef_window.h"

// The pane grid's horizontal scrollbar, shown while the panes (at their
// minimum width) are wider than the window: a thin rounded thumb in a strip
// under the panes, in openp41ge's colours. Dragging the thumb, clicking the
// track or scrolling sideways over it scrolls the grid.
//
// A native view in a small transparent panel of its own, attached to the
// browser window (CEF's own views don't receive the mouse, and the window's
// content view keeps all clicks for CEF's views).
class GridScrollbar {
 public:
  static constexpr int kHeight = 10;

  // Called with the new scroll offset.
  GridScrollbar(CefRefPtr<CefWindow> window, std::function<void(int offset)> on_scroll);
  ~GridScrollbar();

  // Shows it over `strip` (CEF screen coordinates) for a grid `content`
  // wide seen through `viewport`, scrolled by `offset`; or hides it.
  void Update(const CefRect& strip, int content, int viewport, int offset);
  void Hide();

 private:
  struct Native;

  CefRefPtr<CefWindow> window_;
  std::function<void(int)> on_scroll_;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_GRID_SCROLLBAR_H_
