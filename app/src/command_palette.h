// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_COMMAND_PALETTE_H_
#define OPENP41GE_EXPLORER_COMMAND_PALETTE_H_

#include "include/views/cef_window.h"

#include "ui/ui_view.h"

class BrowserWindow;

// The command palette (app/ui/palette.html): where addresses and searches
// are typed. Cmd+L opens it for the active tab, Cmd+T (or a tab bar's +)
// for a new tab.
//
// It floats over the browser window in a small frameless window of its own:
// views layered inside a window stop the window's other web views getting
// clicks, so floating UI gets its own window (as Chrome does for its
// address-bar dropdown). It hides when it loses focus.
//
// Messages from the page: {"type": "go", "url"}, {"type": "dismiss"}.
// Messages to it: {"type": "open", "newTab", "text"}.
class CommandPalette : public UiView, public CefWindowDelegate {
 public:
  static constexpr int kWidth = 560;
  static constexpr int kHeight = 56;

  CommandPalette();

  // Opens over `target`, for its active tab or a new tab in its active pane.
  void Show(BrowserWindow* target, bool new_tab);
  void Hide();
  // `window` is going away.
  void Forget(BrowserWindow* window);
  void Close();

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  bool IsFrameless(CefRefPtr<CefWindow> window) override { return true; }
  bool CanResize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMinimize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMaximize(CefRefPtr<CefWindow> window) override { return false; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }

 protected:
  void OnConnected() override;
  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override;

 private:
  void Place();
  void SendOpen();

  CefRefPtr<CefWindow> window_;
  CefRect bounds_;
  BrowserWindow* target_ = nullptr;
  bool new_tab_ = false;
  bool shown_ = false;

  IMPLEMENT_REFCOUNTING(CommandPalette);
};

#endif  // OPENP41GE_EXPLORER_COMMAND_PALETTE_H_
