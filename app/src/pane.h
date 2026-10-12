// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_PANE_H_
#define OPENP41GE_EXPLORER_PANE_H_

#include <vector>

#include "include/views/cef_panel.h"

#include "tab.h"
#include "tab_bar.h"

class BrowserWindow;

// One pane of a window's grid (a column): a tab bar above the active tab's
// page. The other tabs' pages are kept alive outside the window.
class Pane {
 public:
  // Its share of the grid's width (a flex weight; panes start equal).
  int weight = 1000;

  explicit Pane(BrowserWindow* window);
  ~Pane();

  // The pane's view (tab bar + page), created on first call.
  CefRefPtr<CefPanel> panel();
  CefRefPtr<CefBrowserView> tab_bar_view() { return tab_bar_->view(); }
  BrowserWindow* window() const { return window_; }

  const std::vector<CefRefPtr<Tab>>& tabs() const { return tabs_; }
  CefRefPtr<Tab> active_tab() const { return active_; }
  CefRefPtr<Tab> Find(int id) const;
  CefRefPtr<Tab> Find(CefRefPtr<CefBrowser> browser) const;

  // Adds `tab` at `index` (-1: after the active tab).
  void Add(CefRefPtr<Tab> tab, int index, bool activate);
  // Takes `tab` out of the pane. A new tab becomes active if it was.
  void Remove(CefRefPtr<Tab> tab);
  void Activate(int id);
  // The tab `delta` places along (wrapping), e.g. Cmd+Shift+] is 1.
  void ActivateRelative(int delta);
  void Move(int id, int index);

  // From the tab bar.
  void RequestActivate(int id);
  void RequestClose(int id);
  void RequestNewTab();
  // Loads `url` (typed in the tab's address) in the tab, and focuses it.
  void RequestNavigate(int id, const std::string& url);
  // Where each tab sits in the tab bar (its middle, in the bar's
  // coordinates), for working out where a dragged tab would be inserted.
  void SetTabMiddles(std::vector<std::pair<int, int>> middles) { tab_middles_ = std::move(middles); }
  // Where the active tab's focus bar goes along the tab bar (from, to; empty
  // if it's out of view), from the tab bar.
  void SetFocusBar(CefRange range) { focus_bar_ = range; }
  CefRange focus_bar() const { return focus_bar_; }
  // The index a tab dropped at `x` (tab bar coordinates) would get.
  int InsertIndexAt(int x) const;
  // Shows where a dragged tab would go in the tab bar (-1: nowhere).
  void ShowInsertHint(int index) { tab_bar_->ShowInsertHint(index); }
  int IndexOf(int id) const;
  // A tab's title, address, icon or loading state changed.
  void UpdateTabBar();
  // A suggestion under a tab's address was clicked.
  void PickSuggestion(int index) { tab_bar_->PickSuggestion(index); }
  // A suggestion's ✕ was clicked: forget it.
  void RemoveSuggestion(int index) { tab_bar_->RemoveSuggestion(index); }
  // Focuses tab `id`'s address in the tab bar, to type an address or a
  // search.
  void EditAddress(int id);

 private:
  class Delegate;

  void ShowActive();

  BrowserWindow* window_;
  CefRefPtr<TabBar> tab_bar_;
  CefRefPtr<Delegate> delegate_;
  CefRefPtr<CefPanel> panel_;
  CefRefPtr<CefPanel> content_;  // Holds the active tab's view.
  std::vector<CefRefPtr<Tab>> tabs_;
  CefRefPtr<Tab> active_;
  std::vector<std::pair<int, int>> tab_middles_;  // (tab id, middle x)
  CefRange focus_bar_;
};

#endif  // OPENP41GE_EXPLORER_PANE_H_
