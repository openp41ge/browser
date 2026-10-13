// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_FIND_BAR_H_
#define OPENP41GE_EXPLORER_FIND_BAR_H_

#include <functional>
#include <memory>
#include <string>

#include "include/views/cef_window.h"
#include "ui/ui_view.h"

// Find in page (app/ui/findbar.html): a 35px row over the bottom of a pane's
// page. The pane places it and says what to show; one per pane, made on
// first use and hidden in between. It takes the keyboard while it's in use.
//
// Anything that floats over pages is a window, and this one is a plain
// borderless window of our own (a child of the browser window, so it moves
// with it) with the page in it: CEF makes its windows as titled windows,
// which macOS 26 draws with rounded corners even once made borderless, and
// the row is square, flush with the page (its bottom corners rounded as the
// browser window's, which it sits on).
//
// It covers the page's bottom 35px, so while it shows the page gets as much
// room again at its end (see Pane), and its last lines can scroll clear: the
// page itself isn't resized, so nothing on it moves.
class FindBar : public CefBaseRefCounted {
 public:
  static constexpr int kHeight = 35;

  struct Callbacks {
    // The next match of `text`, forward or back (the first, for new text).
    std::function<void(const std::string& text, bool forward)> find;
    std::function<void()> close;
  };

  // Where it goes: over the bottom of the page (CEF screen coordinates),
  // and which of the browser window's edges that's on. On those it's inset
  // by the window's outline (a pixel, which macOS draws along the edge), so
  // the outline still shows; at the window's bottom corners it's rounded as
  // they are.
  struct Placement {
    CefRect bounds;
    bool left = false;
    bool right = false;
    bool bottom = false;
  };

  FindBar(CefRefPtr<CefWindow> parent, Callbacks callbacks);
  ~FindBar() override;

  // Shows it at `placement` with `text`, the keyboard in its field.
  void Open(const Placement& placement, const std::string& text);
  // Follows its pane (while shown).
  void MoveTo(const Placement& placement);
  void ShowResult(int count, int active);
  void Hide();
  bool IsShown() const { return wanted_; }
  // The pane is going.
  void Close();

 private:
  class Page;
  struct Native;

  // From the page.
  void OnConnected();
  void OnFind(const std::string& text, bool forward);
  void OnClose();
  void SendOpen();
  // Shows the window and gives its page the keyboard.
  void Present();
  void Place(const Placement& placement);

  CefRefPtr<CefWindow> parent_;
  Callbacks callbacks_;
  CefRefPtr<Page> page_;
  std::unique_ptr<Native> native_;
  std::string text_;
  bool wanted_ = false;  // Shown, not hidden.

  IMPLEMENT_REFCOUNTING(FindBar);
};

#endif  // OPENP41GE_EXPLORER_FIND_BAR_H_
