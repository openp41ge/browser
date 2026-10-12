// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_
#define OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_

#include <functional>

#include "include/views/cef_window.h"

#include "ui/ui_view.h"

// Suggestions under a tab whose address is being typed
// (app/ui/suggestions.html): a borderless window of its own over the
// browser window (anything that floats over pages is a window). It never
// takes the keyboard, so typing carries on in the tab; the tab bar chooses
// the rows and which is selected, and this shows them. One per browser
// window, made on first use and hidden in between.
//
// Messages to the page: {"type": "rows", "rows": [{title, detail, kind}],
// "selected"}. From it: {"type": "size", "height"} (once it has laid the
// rows out; the window shows then), {"type": "pick", "index"} (a click),
// {"type": "remove", "index"} (a click on a history row's ✕).
class SuggestionsPopup : public CefWindowDelegate {
 public:
  using PickCallback = std::function<void(int index)>;

  SuggestionsPopup(CefRefPtr<CefWindow> parent, PickCallback pick, PickCallback remove);
  ~SuggestionsPopup() override;

  // Shows `rows` (with `selected` highlighted) under `anchor` (the tab,
  // in screen coordinates), `width` wide.
  void Show(CefRefPtr<CefListValue> rows, int selected, const CefRect& anchor, int width);
  void Hide();
  // The browser window is closing.
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
  void OnSize(int height);
  void OnPick(int index);
  void OnRemove(int index);
  void SendRows();

  CefRefPtr<CefWindow> parent_;
  PickCallback pick_;
  PickCallback remove_;
  CefRefPtr<Page> page_;
  CefRefPtr<CefWindow> window_;
  CefRect bounds_;
  CefRefPtr<CefListValue> rows_;
  int selected_ = 0;
  bool wanted_ = false;  // Shown (once the page has its size), not hidden.

  IMPLEMENT_REFCOUNTING(SuggestionsPopup);
};

#endif  // OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_
