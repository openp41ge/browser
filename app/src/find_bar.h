// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_FIND_BAR_H_
#define OPENP41GE_EXPLORER_FIND_BAR_H_

#include <functional>
#include <string>

#include "include/views/cef_window.h"
#include "ui/ui_view.h"

// Find in page (app/ui/findbar.html): a 35px row over the bottom of a pane's
// page, in a borderless window of its own (anything that floats over pages
// is a window). It takes the keyboard while it's in use. The pane places it
// and says what to show; one per pane, made on first use and hidden in
// between.
//
// It covers the page's bottom 35px, so while it shows the page gets as much
// room again at its end (see Pane), and its last lines can scroll clear: the
// page itself isn't resized, so nothing on it moves.
class FindBar : public CefWindowDelegate {
 public:
  static constexpr int kHeight = 35;

  struct Callbacks {
    // The next match of `text`, forward or back (the first, for new text).
    std::function<void(const std::string& text, bool forward)> find;
    std::function<void()> close;
  };

  FindBar(CefRefPtr<CefWindow> parent, Callbacks callbacks);
  ~FindBar() override;

  // Shows it at `bounds` (screen) with `text`, the keyboard in its field.
  void Open(const CefRect& bounds, const std::string& text);
  // Follows its pane (while shown).
  void MoveTo(const CefRect& bounds);
  void ShowResult(int count, int active);
  void Hide();
  bool IsShown() const { return wanted_; }
  // The pane is going.
  void Close();

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  CefRefPtr<CefWindow> GetParentWindow(CefRefPtr<CefWindow> window, bool* is_menu, bool* can_activate_menu) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }
  bool IsFrameless(CefRefPtr<CefWindow> window) override { return true; }
  bool CanResize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMinimize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanMaximize(CefRefPtr<CefWindow> window) override { return false; }
  bool CanClose(CefRefPtr<CefWindow> window) override { return true; }

 private:
  class Page;

  // From the page.
  void OnConnected();
  void OnFind(const std::string& text, bool forward);
  void OnClose();
  void SendOpen();

  CefRefPtr<CefWindow> parent_;
  Callbacks callbacks_;
  CefRefPtr<Page> page_;
  CefRefPtr<CefWindow> window_;
  CefRect bounds_;
  std::string text_;
  bool wanted_ = false;  // Shown, not hidden.

  IMPLEMENT_REFCOUNTING(FindBar);
};

#endif  // OPENP41GE_EXPLORER_FIND_BAR_H_
