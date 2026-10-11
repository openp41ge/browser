// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TOP_BAR_H_
#define OPENP41GE_EXPLORER_TOP_BAR_H_

#include "ui/ui_view.h"

class BrowserWindow;

// A window's top bar (app/ui/topbar.html): the traffic lights' space, back,
// forward and reload for the active tab. Its empty parts drag the window.
//
// Messages from the page: back, forward, reload, stop.
// Messages to it: {"type": "state", "canGoBack", "canGoForward", "loading"}.
class TopBar : public UiView {
 public:
  // Matches the openp41ge app's title bar.
  static constexpr int kHeight = 35;

  explicit TopBar(BrowserWindow* owner);

  // The active tab changed or its state did.
  void Update();
  // The window is going away.
  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override { Update(); }
  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override;
  void OnDragRegions(const std::vector<CefDraggableRegion>& regions) override;

 private:
  BrowserWindow* owner_;  // Null once the window has gone.

  IMPLEMENT_REFCOUNTING(TopBar);
};

#endif  // OPENP41GE_EXPLORER_TOP_BAR_H_
