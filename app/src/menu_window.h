// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_MENU_WINDOW_H_
#define OPENP41GE_EXPLORER_MENU_WINDOW_H_

#include <functional>
#include <string>
#include <vector>

#include "include/views/cef_window.h"

#include "ui/ui_view.h"

// Our own menu (app/ui/menu.html), e.g. the top bar's: a small borderless
// window of its own over the browser window (anything that floats over pages
// is a window: views layered in the window would stop the pages getting
// clicks). It closes once an item is chosen, on Escape, or when it loses
// focus (a click anywhere else).
//
// Messages from the page: {"type": "size", "width", "height"} (once it has
// laid out its items; the window is shown then), {"type": "run", "id"},
// {"type": "close"}.
// Messages to it: {"type": "items", "items": [{id, label, enabled} |
// {separator: true}]}.
class MenuWindow : public CefWindowDelegate {
 public:
  struct Item {
    int id = -1;  // -1: a separator.
    std::string label;
    bool enabled = true;
  };
  using RunCallback = std::function<void(int id)>;

  // Opens a menu of `items` over `parent` with its top right at
  // `top_right` (screen coordinates), closing any other. `run` gets the
  // chosen item's id, after the menu has closed.
  static void Show(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run);

  ~MenuWindow() override;

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  CefRefPtr<CefWindow> GetParentWindow(CefRefPtr<CefWindow> window, bool* is_menu, bool* can_activate_menu) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override;
  bool IsFrameless(CefRefPtr<CefWindow> window) override { return true; }
  bool CanResize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMinimize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMaximize(CefRefPtr<CefWindow> window) override { return false; }

 private:
  class Page;

  MenuWindow(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run);

  // From the page.
  void OnConnected();
  void OnSize(int width, int height);
  void Run(int id);
  void Close();

  CefRefPtr<CefWindow> parent_;
  CefPoint top_right_;
  std::vector<Item> items_;
  RunCallback run_;
  CefRefPtr<Page> page_;
  CefRefPtr<CefWindow> window_;
  bool shown_ = false;

  IMPLEMENT_REFCOUNTING(MenuWindow);
};

#endif  // OPENP41GE_EXPLORER_MENU_WINDOW_H_
