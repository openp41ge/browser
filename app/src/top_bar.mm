// Copyright (c) 2026 Richard Kielty. MIT License.

#include "top_bar.h"

#include "browser_window.h"

TopBar::TopBar(BrowserWindow* owner) : UiView("topbar.html", kHeight, Background::kGutter), owner_(owner) {}

void TopBar::Update() {
  CefRefPtr<CefBrowser> page = owner_ ? owner_->active_browser() : nullptr;
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "state");
  message->SetBool("canGoBack", page && page->CanGoBack());
  message->SetBool("canGoForward", page && page->CanGoForward());
  message->SetBool("loading", page && page->IsLoading());
  Send(message);
}

bool TopBar::OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) {
  CefRefPtr<CefBrowser> page = owner_ ? owner_->active_browser() : nullptr;
  if (type == "back") {
    if (page) page->GoBack();
  } else if (type == "forward") {
    if (page) page->GoForward();
  } else if (type == "reload") {
    if (page) page->Reload();
  } else if (type == "stop") {
    if (page) page->StopLoad();
  } else {
    return false;
  }
  return true;
}

void TopBar::OnDragRegions(const std::vector<CefDraggableRegion>& regions) {
  // The bar sits at the window's top left, so its coordinates are the
  // window's.
  if (owner_ && owner_->window()) owner_->window()->SetDraggableRegions(regions);
}
