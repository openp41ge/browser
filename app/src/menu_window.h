// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_MENU_WINDOW_H_
#define OPENP41GE_EXPLORER_MENU_WINDOW_H_

#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "include/views/cef_window.h"

#include "ui/ui_view.h"

// Our own menu (app/ui/menu.html), e.g. the top bar's: a small borderless
// window of its own over the browser window (anything that floats over pages
// is a window: views layered in the window would stop the pages getting
// clicks). It's a plain window of ours, not a CEF window, which macOS would
// draw with rounded corners that cut across the menu's square border
// (UiView::CreateIn). It closes once an item is chosen, on Escape, or when
// it loses the keyboard (a click anywhere else).
//
// Messages from the page: {"type": "size", "width", "height"} (once it has
// laid out its items; the window is shown then), {"type": "run", "id"},
// {"type": "close"}.
// Messages to it: {"type": "items", "items": [{id, label, enabled} |
// {separator: true}]}.
class MenuWindow : public CefBaseRefCounted {
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

 private:
  class Page;
  struct Native;

  MenuWindow(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run);
  void Open();

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
  std::unique_ptr<Native> native_;
  bool shown_ = false;

  IMPLEMENT_REFCOUNTING(MenuWindow);
};

#endif  // OPENP41GE_EXPLORER_MENU_WINDOW_H_
