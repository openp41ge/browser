// Copyright (c) 2026 Richard Kielty. MIT License.

#include "command_palette.h"

#include "include/views/cef_fill_layout.h"

#include "browser_window.h"

CommandPalette::CommandPalette() : UiView("palette.html", 0, Background::kSurface) {}

void CommandPalette::Show(BrowserWindow* target, bool new_tab) {
  target_ = target;
  new_tab_ = new_tab;
  shown_ = true;
  Place();
  if (!window_) {
    CefWindow::CreateTopLevelWindow(this);  // Shown in OnWindowCreated.
    return;
  }
  window_->SetBounds(bounds_);
  window_->Show();
  window_->Activate();
  view()->RequestFocus();
  SendOpen();
}

void CommandPalette::Hide() {
  shown_ = false;
  if (window_) window_->Hide();
}

void CommandPalette::Forget(BrowserWindow* window) {
  if (target_ != window) return;
  target_ = nullptr;
  Hide();
}

void CommandPalette::Close() {
  if (window_) window_->Close();
}

void CommandPalette::Place() {
  // Centred near the top of the browser window, just below its top bar.
  if (!target_ || !target_->window()) return;
  const CefRect w = target_->window()->GetBounds();
  bounds_ = CefRect(w.x + (w.width - kWidth) / 2, w.y + TopBar::kHeight + 12, kWidth, kHeight);
}

void CommandPalette::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  window->SetToFillLayout();
  window->AddChildView(view());
  window->SetAlwaysOnTop(true);
  window->Show();
  window->Activate();
  view()->RequestFocus();
  SendOpen();
}

void CommandPalette::OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) {
  // Like a menu: clicking anywhere else dismisses it.
  if (!active && shown_) Hide();
}

void CommandPalette::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  window_ = nullptr;
  target_ = nullptr;
}

void CommandPalette::OnConnected() {
  if (shown_) SendOpen();
}

void CommandPalette::SendOpen() {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "open");
  message->SetBool("newTab", new_tab_);
  CefRefPtr<Tab> tab = target_ && !new_tab_ ? target_->active_tab() : nullptr;
  message->SetString("text", tab && tab->url != "about:blank" ? tab->url : "");
  Send(message);
}

bool CommandPalette::OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) {
  if (type == "go") {
    BrowserWindow* target = target_;
    const bool new_tab = new_tab_;
    Hide();
    if (!target) return true;
    const std::string url = message->GetString("url");
    if (new_tab) {
      target->OpenTab(url);
    } else if (CefRefPtr<CefBrowser> page = target->active_browser()) {
      page->GetMainFrame()->LoadURL(url);
    }
    if (target->window()) target->window()->Activate();
    if (CefRefPtr<Tab> tab = target->active_tab()) tab->view()->RequestFocus();
  } else if (type == "dismiss") {
    BrowserWindow* target = target_;
    Hide();
    if (target && target->window()) target->window()->Activate();
  } else {
    return false;
  }
  return true;
}
