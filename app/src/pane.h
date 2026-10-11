// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_PANE_H_
#define OPENP41GE_EXPLORER_PANE_H_

#include <vector>

#include "include/views/cef_panel.h"

#include "tab.h"
#include "tab_bar.h"

class BrowserWindow;

// One pane of a window's grid: a tab bar above the active tab's page. The
// other tabs' pages are kept alive outside the window.
class Pane {
 public:
  explicit Pane(BrowserWindow* window);
  ~Pane();

  // The pane's view (tab bar + page), created on first call.
  CefRefPtr<CefPanel> panel();
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
  void RequestClose(int id);
  void RequestNewTab();
  // A tab's title, address, icon or loading state changed.
  void UpdateTabBar();

 private:
  void ShowActive();

  BrowserWindow* window_;
  CefRefPtr<TabBar> tab_bar_;
  CefRefPtr<CefPanel> panel_;
  CefRefPtr<CefPanel> content_;  // Holds the active tab's view.
  std::vector<CefRefPtr<Tab>> tabs_;
  CefRefPtr<Tab> active_;
};

#endif  // OPENP41GE_EXPLORER_PANE_H_
