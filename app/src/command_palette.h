// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_COMMAND_PALETTE_H_
#define OPENP41GE_EXPLORER_COMMAND_PALETTE_H_

#include <memory>

#include "ui/ui_view.h"

class BrowserWindow;

// A browser window's command palette (app/ui/palette.html): where addresses
// and searches are typed. Cmd+L opens it for the active tab, Cmd+T (or a tab
// bar's +) for a new tab.
//
// It floats over the browser window in a borderless panel of our own,
// attached to the browser window so it moves with it, with the page hosted
// inside it (views layered inside a window stop the window's other web
// views getting clicks, and CEF's own windows always keep a hidden title
// bar). It hides when it loses focus.
//
// Messages from the page: {"type": "go", "url"}, {"type": "dismiss"}.
// Messages to it: {"type": "open", "newTab", "text"}.
class CommandPalette : public UiView {
 public:
  static constexpr int kWidth = 560;
  static constexpr int kHeight = 56;

  explicit CommandPalette(BrowserWindow* owner);
  ~CommandPalette() override;

  // Opens it, for the window's active tab or a new tab in its active pane.
  void Show(bool new_tab);
  void Hide();
  // The browser window is going away.
  void Detach();

 protected:
  void OnConnected() override;
  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override;

 private:
  struct Native;  // The Cocoa panel (command_palette.mm).

  void SendOpen();

  BrowserWindow* owner_;  // Null once the browser window has gone.
  std::unique_ptr<Native> native_;
  bool new_tab_ = false;
  bool shown_ = false;

  IMPLEMENT_REFCOUNTING(CommandPalette);
};

#endif  // OPENP41GE_EXPLORER_COMMAND_PALETTE_H_
