// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_BAR_H_
#define OPENP41GE_EXPLORER_TAB_BAR_H_

#include "ui/ui_view.h"

class Pane;

// A pane's tab bar (app/ui/tabbar.html), after openp41ge's tab bar.
//
// Messages from the page: {"type": "activate", "id"}, {"type": "close",
// "id"}, {"type": "move", "id", "index"} (reorder), {"type": "new-tab"}.
// Messages to it: {"type": "tabs", "tabs": [{id, title, url, favicon,
// loading}], "active": id}.
class TabBar : public UiView {
 public:
  static constexpr int kHeight = 35;

  explicit TabBar(Pane* owner);

  // The pane's tabs changed.
  void Update();
  // The pane is going away.
  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override { Update(); }
  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override;

 private:
  Pane* owner_;  // Null once the pane has gone.

  IMPLEMENT_REFCOUNTING(TabBar);
};

#endif  // OPENP41GE_EXPLORER_TAB_BAR_H_
