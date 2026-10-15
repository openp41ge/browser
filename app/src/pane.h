// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_PANE_H_
#define OPENP41GE_EXPLORER_PANE_H_

#include <vector>

#include "include/views/cef_panel.h"
#include "find_bar.h"

#include "tab.h"
#include "tab_bar.h"

class BrowserWindow;

// One pane of a window's grid (a column): a tab bar above the active tab's
// page. Every tab's page is in the pane, hidden unless its tab is active:
// CEF only makes a page once its view is in a window, so this is what has a
// tab opened behind (Cmd-click) load straight away, as Chrome's do.
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
  // Its tabs, brought back: `active` shows (loading if it isn't).
  void Restore(std::vector<CefRefPtr<Tab>> tabs, int active);
  void Activate(int id);
  // The tab `delta` places along (wrapping), e.g. Cmd+Shift+] is 1.
  void ActivateRelative(int delta);
  void Move(int id, int index);

  // From the tab bar.
  void RequestActivate(int id);
  void RequestClose(int id);
  // Mutes the tab, or unmutes it.
  void RequestMute(int id);
  void RequestNewTab();
  // Loads `url` (typed in the tab's address) in the tab, and focuses it.
  void RequestNavigate(int id, const std::string& url);
  // Where each tab sits in the tab bar (its middle, in the bar's
  // coordinates), for working out where a dragged tab would be inserted.
  void SetTabMiddles(std::vector<std::pair<int, int>> middles) { tab_middles_ = std::move(middles); }
  // Where the active tab's focus bar goes along the tab bar, from the tab
  // bar: centred on `middle`, within `visible` (the part of the tab in view;
  // empty if it's out of view).
  void SetFocusBar(int middle, CefRange visible) {
    focus_bar_middle_ = middle;
    focus_bar_ = visible;
  }
  int focus_bar_middle() const { return focus_bar_middle_; }
  CefRange focus_bar() const { return focus_bar_; }
  // The index a tab dropped at `x` (tab bar coordinates) would get.
  int InsertIndexAt(int x) const;
  // Shows where a dragged tab would go in the tab bar (-1: nowhere).
  void ShowInsertHint(int index) { tab_bar_->ShowInsertHint(index); }
  int IndexOf(int id) const;
  // A tab's title, address, icon, loading state or picture changed.
  void UpdateTabBar();
  // A suggestion under a tab's address was clicked.
  void PickSuggestion(int index) { tab_bar_->PickSuggestion(index); }
  // A suggestion's ✕ was clicked: forget it.
  void RemoveSuggestion(int index) { tab_bar_->RemoveSuggestion(index); }
  // Focuses tab `id`'s address in the tab bar, to type an address or a
  // search.
  void EditAddress(int id);

  // Find in page, in the active tab: opens its find row (or brings the
  // keyboard back to it), closes it, or moves to the next or previous match.
  void OpenFind();
  void CloseFind();
  void FindAgain(bool forward);
  bool CanFindAgain() const;
  // From the browser: `tab`'s matches.
  void OnFindResult(CefRefPtr<Tab> tab, int count, int active);
  // `tab`'s page has loaded: while it's finding, its room for the find row.
  void OnPageLoaded(CefRefPtr<Tab> tab);
  // Shows, places or hides the find row for the active tab (after a
  // layout, or a tab switch).
  void UpdateFindBar();
  // Shows the active tab's page and hides the others, except one with an
  // element popped out (see ShowPages).
  void ShowPages();

 private:
  // `tab` stops being the active one: when, for its preview.
  static void Leave(CefRefPtr<Tab> tab);
  class Delegate;

  void AddView(CefRefPtr<Tab> tab);
  void ShowActive();
  void Find(const std::string& text, bool forward);
  // Room at the end of `tab`'s page for the find row over it, or none.
  void SetFindRoom(CefRefPtr<Tab> tab, bool room);
  FindBar::Placement FindBarPlacement() const;

  BrowserWindow* window_;
  CefRefPtr<TabBar> tab_bar_;
  CefRefPtr<Delegate> delegate_;
  CefRefPtr<CefPanel> panel_;
  CefRefPtr<CefPanel> content_;  // Holds every tab's view; the active one shows.
  std::vector<CefRefPtr<Tab>> tabs_;
  CefRefPtr<Tab> active_;
  std::vector<std::pair<int, int>> tab_middles_;  // (tab id, middle x)
  int focus_bar_middle_ = 0;
  CefRange focus_bar_;
  CefRefPtr<FindBar> find_bar_;  // Made on first use.
};

#endif  // OPENP41GE_EXPLORER_PANE_H_
