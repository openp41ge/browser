// Copyright (c) 2026 Richard Kielty. MIT License.

#include "top_bar.h"

#include "browser_manager.h"
#include "browser_window.h"
#include "menu_window.h"
#include "updater.h"

namespace {

using Command = BrowserManager::Command;

// The menu button's menu: browser commands, as in the menu bar.
std::vector<MenuWindow::Item> MenuItems() {
  BrowserManager* manager = BrowserManager::Get();
  std::vector<MenuWindow::Item> items;
  auto add = [&](Command command, const std::string& label) {
    items.push_back({static_cast<int>(command), label, manager && manager->CanRun(command)});
  };
  auto separator = [&] { items.push_back({}); };
  // An update waiting for the user, first (the button says so too).
  const std::string update = updater::AvailableVersion();
  if (!update.empty()) {
    add(Command::kUpdate, "Update to " + update);
    separator();
  }
  add(Command::kNewTab, "New Tab");
  add(Command::kNewWindow, "New Window");
  add(Command::kNewPrivateWindow, "New Private Window");
  add(Command::kReopenClosed,
      manager && manager->NextReopenIsWindow() ? "Reopen Closed Window" : "Reopen Closed Tab");
  separator();
  add(Command::kZoomIn, "Zoom In");
  add(Command::kZoomOut, "Zoom Out");
  add(Command::kZoomReset, "Actual Size");
  separator();
  add(Command::kFind, "Find…");
  add(Command::kPrint, "Print…");
  separator();
  add(Command::kExtensions, "Extensions");
  add(Command::kDevTools, "Developer Tools");
  return items;
}

}  // namespace

TopBar::TopBar(BrowserWindow* owner) : UiView("topbar.html", CefSize(1, kHeight), Background::kGutter), owner_(owner) {}

void TopBar::Update() {
  CefRefPtr<CefBrowser> page = owner_ ? owner_->active_browser() : nullptr;
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "state");
  message->SetBool("canGoBack", page && page->CanGoBack());
  message->SetBool("canGoForward", page && page->CanGoForward());
  CefRefPtr<Tab> tab = owner_ ? owner_->active_tab() : nullptr;
  message->SetString("title", tab ? tab->title : std::string());
  message->SetBool("private", owner_ && owner_->is_private());
  message->SetString("update", updater::AvailableVersion());
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
  } else if (type == "menu") {
    CefPoint point(message->GetInt("x"), message->GetInt("y"));
    if (owner_ && owner_->window() && view()->ConvertPointToScreen(point)) {
      MenuWindow::Show(owner_->window(), point, MenuItems(), [](int id) {
        if (BrowserManager* manager = BrowserManager::Get()) manager->Run(static_cast<Command>(id));
      });
    }
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
