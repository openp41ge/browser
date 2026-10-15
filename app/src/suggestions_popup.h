// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_
#define OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_

#include <functional>
#include <memory>

#include "include/views/cef_window.h"

#include "ui/ui_view.h"

// Suggestions under a tab whose address is being typed
// (app/ui/suggestions.html), placed as the tab's preview is: a card hanging
// from the tab bar's bottom edge, its top square against it and its bottom
// corners rounded (but where it meets the window's side), centred on the
// tab and kept within the window, as tall as its rows, or as many whole
// rows as fit above the window's bottom (the rest scroll). A borderless
// panel of our own over the browser window (anything that floats over pages
// is a window; a CEF window would get macOS's own outline and corners). It
// never takes the keyboard, so typing carries on in the tab; the tab bar
// chooses the rows and which is selected, and this shows them. One per
// browser window, made on first use and hidden in between.
//
// Messages to the page: {"type": "rows", "rows": [{title, detail, kind}],
// "selected", "maxHeight", "squareLeft", "squareRight"}. From it:
// {"type": "size", "height"} (once it has laid the rows out; the panel shows
// then), {"type": "pick", "index"} (a click), {"type": "remove", "index"} (a
// click on a history row's ✕).
class SuggestionsPopup : public CefBaseRefCounted {
 public:
  using PickCallback = std::function<void(int index)>;

  SuggestionsPopup(CefRefPtr<CefWindow> parent, PickCallback pick, PickCallback remove);
  ~SuggestionsPopup() override;

  // Shows `rows` (with `selected` highlighted) under `anchor` (the tab, down
  // to the tab bar's bottom edge, in screen coordinates), `width` wide.
  void Show(CefRefPtr<CefListValue> rows, int selected, const CefRect& anchor, int width);
  void Hide();
  // The browser window is closing.
  void Close();

 private:
  class Page;
  struct Native;

  // From the page.
  void OnConnected();
  void OnSize(int height);
  void OnPick(int index);
  void OnRemove(int index);
  void SendRows();
  // Its frame, for its height now.
  void Place();
  void SetPageHidden(bool hidden);

  CefRefPtr<CefWindow> parent_;
  PickCallback pick_;
  PickCallback remove_;
  CefRefPtr<Page> page_;
  std::unique_ptr<Native> native_;
  CefRect bounds_;      // Where it goes (screen coordinates); its height, the rows'.
  int max_height_ = 0;  // Down to the window's bottom.
  bool square_left_ = false;
  bool square_right_ = false;
  CefRefPtr<CefListValue> rows_;
  int selected_ = 0;
  bool wanted_ = false;  // Shown (once the page has its size), not hidden.

  IMPLEMENT_REFCOUNTING(SuggestionsPopup);
};

#endif  // OPENP41GE_EXPLORER_SUGGESTIONS_POPUP_H_
