// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_DIVIDER_HANDLES_H_
#define OPENP41GE_EXPLORER_DIVIDER_HANDLES_H_

#include <functional>
#include <memory>
#include <vector>

#include "include/views/cef_window.h"

// The grab areas over the dividers between panes, after openp41ge's: 5px
// wide, centred on each 1px divider line and taking no space of their own;
// the resize cursor; a 3px blue line that fades in on hover or while
// dragging. Dragging resizes the panes either side, double-clicking makes
// all panes equal.
//
// Each is a native view in a small transparent panel of its own, attached
// to the browser window (CEF's own views don't receive the mouse, a layered
// CEF view would stop the window's web views getting clicks, and the
// window's content view keeps all clicks for CEF's views).
class DividerHandles {
 public:
  struct Callbacks {
    // `divider` is between pane `divider` and pane `divider + 1`; x is the
    // pointer on screen.
    std::function<void(int divider, int screen_x)> begin;
    std::function<void(int screen_x)> move;
    std::function<void()> end;
    std::function<void()> reset;
  };

  DividerHandles(CefRefPtr<CefWindow> window, Callbacks callbacks);
  ~DividerHandles();

  // Places one handle centred on each divider line (CEF screen rectangles,
  // in order), removing any spare ones.
  void Update(const std::vector<CefRect>& lines);

 private:
  struct Native;

  CefRefPtr<CefWindow> window_;
  Callbacks callbacks_;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_DIVIDER_HANDLES_H_
