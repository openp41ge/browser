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
// {"type": "toggle-previews"} (its previews button: every tab bar in the
// window grows to show each tab's picture, or back).
// Messages to it: {"type": "tabs", "tabs": [{id, url, title, favicon,
// loading, loaded, preview}] (preview: its picture's address, if it has
// one), "active": id, "focused": bool (the window's active pane, while the
// window is the active one: its active tab is the focused tab), "previews":
// bool (showing them), "edit"?: id (start editing that tab's address)},
// {"type": "hint", "index"} (where a dragged tab
// would go; -1 for nowhere).
class TabBar : public UiView {
 public:
  static constexpr int kHeight = 35;
  // The pictures' height, showing previews: a 220px tab's width at 16:10.
  static constexpr int kPreviewHeight = 138;

  explicit TabBar(Pane* owner);

  // The pane's tabs changed.
  void Update();
  // Taller, with each tab's picture under it; or not.
  void SetPreviews(bool shown);
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
