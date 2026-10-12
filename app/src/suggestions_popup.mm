// Copyright (c) 2026 Richard Kielty. MIT License.

#include "suggestions_popup.h"

#import <Cocoa/Cocoa.h>


#include "include/wrapper/cef_helpers.h"

#include "borderless.h"

namespace {

// A height to start at, before the page reports its own.
constexpr int kInitialHeight = 40;
// The gap between the tab and the popup.
constexpr int kGap = 2;

}  // namespace

class SuggestionsPopup::Page : public UiView {
 public:
  explicit Page(SuggestionsPopup* owner)
      : UiView("suggestions.html", CefSize(1, kInitialHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "size") {
      owner_->OnSize(message->GetInt("height"));
    } else if (type == "pick") {
      owner_->OnPick(message->GetInt("index"));
    } else if (type == "remove") {
      owner_->OnRemove(message->GetInt("index"));
    } else {
      return false;
    }
    return true;
  }

 private:
  SuggestionsPopup* owner_;  // Null once the popup has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

SuggestionsPopup::SuggestionsPopup(CefRefPtr<CefWindow> parent, PickCallback pick, PickCallback remove)
    : parent_(parent), pick_(std::move(pick)), remove_(std::move(remove)), page_(new Page(this)) {}

SuggestionsPopup::~SuggestionsPopup() {
  page_->Detach();
}

void SuggestionsPopup::Show(CefRefPtr<CefListValue> rows, int selected, const CefRect& anchor, int width) {
  CEF_REQUIRE_UI_THREAD();
  // A copy: `rows` belongs to the tab bar's message, gone once it's handled.
  rows_ = rows->Copy();
  selected_ = selected;
  bounds_ = CefRect(anchor.x, anchor.y + anchor.height + kGap, width, bounds_.height > 0 ? bounds_.height : kInitialHeight);
  wanted_ = true;
  if (!window_) {
    // Shown once its page has laid the rows out (OnSize).
    CefWindow::CreateTopLevelWindow(this);
    return;
  }
  SendRows();
}

void SuggestionsPopup::Hide() {
  wanted_ = false;
  if (window_) window_->Hide();
}

void SuggestionsPopup::Close() {
  wanted_ = false;
  pick_ = nullptr;
  remove_ = nullptr;
  if (window_) window_->Close();
}

void SuggestionsPopup::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  MakeBorderless(window);
  // A menu's level. It's never the key window (the keyboard stays in the
  // tab), and web views only follow the pointer (hover) in an inactive
  // window above the normal level.
  ((__bridge NSView*)window->GetWindowHandle()).window.level = NSPopUpMenuWindowLevel;
  window->AddChildView(page_->view());
}

void SuggestionsPopup::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  window_ = nullptr;
}

CefRefPtr<CefWindow> SuggestionsPopup::GetParentWindow(CefRefPtr<CefWindow> window,
                                                       bool* is_menu,
                                                       bool* can_activate_menu) {
  *is_menu = true;
  // The keyboard stays with the tab's address.
  *can_activate_menu = false;
  return parent_;
}

void SuggestionsPopup::OnConnected() {
  SendRows();
}

void SuggestionsPopup::SendRows() {
  if (!rows_) return;
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "rows");
  message->SetList("rows", rows_->Copy());
  message->SetInt("selected", selected_);
  page_->Send(message);
}

void SuggestionsPopup::OnSize(int height) {
  if (!window_ || height <= 0) return;
  bounds_.height = height;
  if (!wanted_) return;
  window_->SetBounds(bounds_);
  if (!window_->IsVisible()) window_->Show();
}

void SuggestionsPopup::OnPick(int index) {
  if (wanted_ && pick_) pick_(index);
}

void SuggestionsPopup::OnRemove(int index) {
  if (wanted_ && remove_) remove_(index);
}
