// Copyright (c) 2026 Richard Kielty. MIT License.

#include "find_bar.h"

#include "include/wrapper/cef_helpers.h"

#include "borderless.h"

class FindBar::Page : public UiView {
 public:
  explicit Page(FindBar* owner) : UiView("findbar.html", CefSize(1, kHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "find") {
      owner_->OnFind(message->GetString("text"), message->GetBool("forward"));
    } else if (type == "close") {
      owner_->OnClose();
    } else {
      return false;
    }
    return true;
  }

 private:
  FindBar* owner_;  // Null once the find bar has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

FindBar::FindBar(CefRefPtr<CefWindow> parent, Callbacks callbacks)
    : parent_(parent), callbacks_(std::move(callbacks)), page_(new Page(this)) {}

FindBar::~FindBar() {
  page_->Detach();
}

void FindBar::Open(const CefRect& bounds, const std::string& text) {
  CEF_REQUIRE_UI_THREAD();
  bounds_ = bounds;
  text_ = text;
  wanted_ = true;
  if (!window_) {
    CefWindow::CreateTopLevelWindow(this);  // Shown in OnWindowCreated.
    return;
  }
  window_->SetBounds(bounds_);
  window_->Show();
  window_->Activate();
  page_->view()->RequestFocus();
  SendOpen();
}

void FindBar::MoveTo(const CefRect& bounds) {
  bounds_ = bounds;
  if (window_ && wanted_) window_->SetBounds(bounds_);
}

void FindBar::ShowResult(int count, int active) {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "result");
  message->SetInt("count", count);
  message->SetInt("active", active);
  page_->Send(message);
}

void FindBar::Hide() {
  wanted_ = false;
  if (window_) window_->Hide();
}

void FindBar::Close() {
  wanted_ = false;
  callbacks_ = {};
  if (window_) window_->Close();
}

void FindBar::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  MakeBorderless(window);
  window->AddChildView(page_->view());
  // Again once it exists: macOS gives a new window a taller minimum.
  window->SetBounds(bounds_);
  if (!wanted_) return;
  window->Show();
  window->Activate();
  page_->view()->RequestFocus();
}

void FindBar::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  window_ = nullptr;
}

CefRefPtr<CefWindow> FindBar::GetParentWindow(CefRefPtr<CefWindow> window, bool* is_menu, bool* can_activate_menu) {
  // A child of the browser window (it moves with it), which can take the
  // keyboard for its field.
  *is_menu = true;
  *can_activate_menu = true;
  return parent_;
}

void FindBar::OnConnected() {
  if (!wanted_) return;
  // The keyboard, again now its page is ready: opened from a menu, the
  // browser window takes it back as the menu closes.
  if (window_) window_->Activate();
  page_->view()->RequestFocus();
  SendOpen();
}

void FindBar::SendOpen() {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "open");
  message->SetString("text", text_);
  page_->Send(message);
}

void FindBar::OnFind(const std::string& text, bool forward) {
  text_ = text;
  if (wanted_ && callbacks_.find) callbacks_.find(text, forward);
}

void FindBar::OnClose() {
  if (wanted_ && callbacks_.close) callbacks_.close();
}
