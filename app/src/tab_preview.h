// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_PREVIEW_H_
#define OPENP41GE_EXPLORER_TAB_PREVIEW_H_

#include <memory>
#include <string>

#include "include/internal/cef_types_wrappers.h"

// A tab's picture (tab_previews.h) shown under it while the pointer rests on
// it: a card hanging from the tab bar's bottom edge, the tab's width, over the
// page below (a native panel of its own, as anything over pages is a
// window), fading in. Square at the top, where it meets the bar; rounded at
// the bottom, but square on a side that meets the column's edge. Under the
// picture, a bar saying when the tab was last accessed. It ignores the mouse, so it
// never comes between the pointer and the tab bar or page. The tab bar
// decides when (after a short rest on a tab that isn't the active one, and
// straight away when the pointer moves on to another while one shows). One
// per browser window, made on first use.
class TabPreview {
 public:
  TabPreview();
  ~TabPreview();

  // Shows `jpeg` under `anchor` (the tab, in CEF screen coordinates, down to
  // the tab bar's bottom edge), `anchor`'s width: fading in if it wasn't
  // showing, moved and swapped in place if it was. `square_left`,
  // `square_right`: its bottom corner on that side square (it meets the
  // column's edge there). `footer`: the bar under the picture (e.g. "Last
  // accessed 5 minutes ago"); none if empty.
  void Show(const std::string& jpeg,
            const CefRect& anchor,
            bool square_left,
            bool square_right,
            const std::string& footer);
  // Fades it out.
  void Hide();

 private:
  struct Native;
  std::unique_ptr<Native> native_;
};

#endif  // OPENP41GE_EXPLORER_TAB_PREVIEW_H_
