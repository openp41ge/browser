// Copyright (c) 2026 Richard Kielty. MIT License.

#include "menu_window.h"

#include "include/base/cef_callback.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

#include "borderless.h"

namespace {

// The open menu, if any (one at a time).
CefRefPtr<MenuWindow> g_open;

// Room the page may not have reported yet: the window starts this size,
// hidden, until the page says how big it is.
constexpr int kInitialWidth = 240;
constexpr int kInitialHeight = 100;

}  // namespace

class MenuWindow::Page : public UiView {
 public:
  explicit Page(MenuWindow* owner)
      : UiView("menu.html", CefSize(kInitialWidth, kInitialHeight), Background::kSurface), owner_(owner) {}

  void Detach() { owner_ = nullptr; }

 protected:
  void OnConnected() override {
    if (owner_) owner_->OnConnected();
  }

  bool OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) override {
    if (!owner_) return true;
    if (type == "size") {
      owner_->OnSize(message->GetInt("width"), message->GetInt("height"));
    } else if (type == "run") {
      owner_->Run(message->GetInt("id"));
    } else if (type == "close") {
      owner_->Close();
    } else {
      return false;
    }
    return true;
  }

 private:
  MenuWindow* owner_;  // Null once the menu has gone.

  IMPLEMENT_REFCOUNTING(Page);
};

void MenuWindow::Show(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run) {
  CEF_REQUIRE_UI_THREAD();
  if (g_open) g_open->Close();
  g_open = new MenuWindow(parent, top_right, std::move(items), std::move(run));
  CefWindow::CreateTopLevelWindow(g_open);
}

MenuWindow::MenuWindow(CefRefPtr<CefWindow> parent, CefPoint top_right, std::vector<Item> items, RunCallback run)
    : parent_(parent), top_right_(top_right), items_(std::move(items)), run_(std::move(run)), page_(new Page(this)) {}

MenuWindow::~MenuWindow() = default;

void MenuWindow::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  MakeBorderless(window);
  window->AddChildView(page_->view());
  // Shown once the page has laid out its items (OnSize).
}

CefRefPtr<CefWindow> MenuWindow::GetParentWindow(CefRefPtr<CefWindow> window, bool* is_menu, bool* can_activate_menu) {
  *is_menu = true;
  *can_activate_menu = true;  // For the keyboard: arrows, Return, Escape.
  return parent_;
}

CefRect MenuWindow::GetInitialBounds(CefRefPtr<CefWindow> window) {
  return CefRect(top_right_.x - kInitialWidth, top_right_.y, kInitialWidth, kInitialHeight);
}

void MenuWindow::OnConnected() {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const Item& item : items_) {
    CefRefPtr<CefDictionaryValue> entry = CefDictionaryValue::Create();
    if (item.id < 0) {
      entry->SetBool("separator", true);
    } else {
      entry->SetInt("id", item.id);
      entry->SetString("label", item.label);
      entry->SetBool("enabled", item.enabled);
    }
    list->SetDictionary(list->GetSize(), entry);
  }
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "items");
  message->SetList("items", list);
  page_->Send(message);
}

void MenuWindow::OnSize(int width, int height) {
  if (!window_ || width <= 0 || height <= 0) return;
  window_->SetBounds(CefRect(top_right_.x - width, top_right_.y, width, height));
  if (!shown_) {
    shown_ = true;
    window_->Show();
    page_->view()->RequestFocus();
  }
}

void MenuWindow::OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) {
  // A click anywhere else.
  if (!active && shown_) Close();
}

void MenuWindow::Run(int id) {
  RunCallback run = std::move(run_);
  Close();
  // Once the menu has gone, so the command acts on the browser window.
  if (run) CefPostTask(TID_UI, base::BindOnce([](RunCallback run, int id) { run(id); }, std::move(run), id));
}

void MenuWindow::Close() {
  run_ = nullptr;
  if (window_) window_->Close();
}

void MenuWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  page_->Detach();
  window_ = nullptr;
  if (g_open.get() == this) g_open = nullptr;
}
