// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_BAR_H_
#define OPENP41GE_EXPLORER_TAB_BAR_H_

#include "ui/ui_view.h"

class Pane;

// A pane's tab bar (app/ui/tabbar.html), after openp41ge's tab bar.
//
// Messages from the page: {"type": "activate", "id"}, {"type": "close",
// "id"}, {"type": "new-tab"}, {"type": "navigate", "id", "url"} (typed in
// the tab's address), {"type": "layout", "tabs": [{id, middle}]}
// (where its tabs are), and while a tab is dragged {"type": "drag", "id",
// "x", "y"}, {"type": "drop", "id", "x", "y"} (in its own coordinates; the
// window works out where it lands) or {"type": "drag-cancel"}.
// {"type": "preview-show", "id", "x", "y", "width", "height", "squareLeft",
// "squareRight"} (the pointer rests on that tab, there in its coordinates
// down to the bar's bottom edge: its picture under it, its width; square
// bottom corners where it meets the column's edges; tab_preview.h; sent
// again as the tab moves or resizes) and {"type": "preview-hide"}.
// Messages to it: {"type": "tabs", "tabs": [{id, url, title, favicon,
// loading, preview}] (preview: whether it has a picture), "active": id,
// "focused": bool (the window's active pane, while the window is the active
// one: its active tab is the focused tab), "edit"?: id (start editing that
// tab's address)},
// {"type": "hint", "index"} (where a dragged tab
// would go; -1 for nowhere).
class TabBar : public UiView {
 public:
  static constexpr int kHeight = 35;

  explicit TabBar(Pane* owner);

  // The pane's tabs changed.
  void Update();
  void ShowInsertHint(int index);
  // A suggestion (its index in the rows the page asked to show) was clicked.
  void PickSuggestion(int index);
  void RemoveSuggestion(int index);
  // Starts editing tab `id`'s address (once the page is listening).
  void EditAddress(int id);
  // The pane is going away.
  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override { Update(); }
  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override;

 private:
  Pane* owner_;  // Null once the pane has gone.
  int edit_ = -1;  // A tab whose address to edit, not yet sent.

  IMPLEMENT_REFCOUNTING(TabBar);
};

#endif  // OPENP41GE_EXPLORER_TAB_BAR_H_
