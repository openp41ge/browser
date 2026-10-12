// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_DROP_PREVIEW_H_
#define OPENP41GE_EXPLORER_DROP_PREVIEW_H_

#include <memory>

#include "include/internal/cef_types_wrappers.h"
#include "include/views/cef_window.h"

// Where a dragged tab will land, drawn over the pages while a tab is
// dragged: a blue ring with a glow and a light wash, after openp41ge's
// drop-box. It's a transparent panel of its own that ignores the mouse
// (views layered inside the window would stop the window's web views
// getting clicks).
class DropPreview {
 public:
  explicit DropPreview(CefRefPtr<CefWindow> parent);
  ~DropPreview();

  // Shows it over `screen_rect` (CEF screen coordinates).
  void Show(const CefRect& screen_rect);
  void Hide();

 private:
  struct Native;

  CefRefPtr<CefWindow> parent_;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_DROP_PREVIEW_H_
