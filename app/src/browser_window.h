// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_WINDOW_H_
#define OPENP41GE_EXPLORER_BROWSER_WINDOW_H_

#include <memory>
#include <string>
#include <vector>

#include "include/views/cef_window.h"

#include "command_palette.h"
#include "pane.h"
#include "top_bar.h"

class BrowserManager;

// A browser window: the top bar above the pane grid (one row of panes, each
// a tab bar above a page). The window is frameless apart from macOS's
// traffic lights, which sit in the top bar.
//
// All of it is Alloy style: our UI in small web views (top bar, tab bars)
// and pages laid out beside them, never overlapping (layered views stop the
// views underneath getting clicks).
class BrowserWindow : public CefWindowDelegate {
 public:
  BrowserWindow(BrowserManager* manager, CefRect bounds, std::string first_url);

  CefRefPtr<CefWindow> window() const { return window_; }
  BrowserManager* manager() const { return manager_; }
  Pane* active_pane() const { return active_pane_; }
  CefRefPtr<Tab> active_tab() const;
  CefRefPtr<CefBrowser> active_browser() const;

  // Opens `url` as a new tab in `pane` (default: the active pane), after its
  // active tab.
  CefRefPtr<Tab> OpenTab(const std::string& url, Pane* pane = nullptr, bool activate = true);
  // Adds a page CEF created (a popup) as a tab beside `opener`'s.
  void AdoptPopup(CefRefPtr<CefBrowser> opener, CefRefPtr<CefBrowserView> view, bool activate);
  // Where `browser`'s tab is, if it's one of this window's.
  Pane* Locate(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab = nullptr) const;

  // Asks the tab's page to close (it may run unload handlers first).
  void CloseTab(CefRefPtr<Tab> tab);
  // The page is closing: its tab goes, and the window if it was the last.
  void OnTabClosed(CefRefPtr<CefBrowser> browser);
  // A page's title, address, icon or loading state changed.
  void OnTabChanged(CefRefPtr<CefBrowser> browser);
  // A pane's active tab changed.
  void OnActiveTabChanged(Pane* pane);
  // Opens the command palette over this window, for the active tab or a new
  // tab in `pane`.
  void ShowPalette(bool new_tab, Pane* pane = nullptr);

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override;
  bool CanClose(CefRefPtr<CefWindow> window) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }
  bool IsFrameless(CefRefPtr<CefWindow> window) override { return true; }
  bool WithStandardWindowButtons(CefRefPtr<CefWindow> window) override { return true; }
  // Centres the traffic lights in the top bar.
  bool GetTitlebarHeight(CefRefPtr<CefWindow> window, float* titlebar_height) override {
    *titlebar_height = TopBar::kHeight;
    return true;
  }

 private:
  void UpdateTitle();

  BrowserManager* manager_;  // Lives as long as the app.
  CefRect bounds_;
  std::string first_url_;
  CefRefPtr<CefWindow> window_;
  CefRefPtr<TopBar> top_bar_;
  CefRefPtr<CommandPalette> palette_;  // Created when first opened.
  std::vector<std::unique_ptr<Pane>> panes_;
  Pane* active_pane_ = nullptr;
  bool closing_ = false;

  IMPLEMENT_REFCOUNTING(BrowserWindow);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_WINDOW_H_
