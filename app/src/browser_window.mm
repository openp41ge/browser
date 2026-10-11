// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_window.h"

#include "include/views/cef_box_layout.h"

#include "browser_manager.h"

BrowserWindow::BrowserWindow(BrowserManager* manager, CefRect bounds, std::string first_url)
    : manager_(manager), bounds_(bounds), first_url_(std::move(first_url)), top_bar_(new TopBar(this)) {}

CefRefPtr<Tab> BrowserWindow::active_tab() const {
  return active_pane_ ? active_pane_->active_tab() : nullptr;
}

CefRefPtr<CefBrowser> BrowserWindow::active_browser() const {
  CefRefPtr<Tab> tab = active_tab();
  return tab ? tab->browser() : nullptr;
}

void BrowserWindow::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  CefBoxLayoutSettings column;
  column.horizontal = false;
  CefRefPtr<CefBoxLayout> layout = window->SetToBoxLayout(column);
  window->AddChildView(top_bar_->view());

  // The grid: one row of panes (one pane for now).
  CefRefPtr<CefPanel> grid = CefPanel::CreatePanel(nullptr);
  CefBoxLayoutSettings row;
  row.horizontal = true;
  CefRefPtr<CefBoxLayout> grid_layout = grid->SetToBoxLayout(row);
  panes_.push_back(std::make_unique<Pane>(this));
  active_pane_ = panes_.back().get();
  grid->AddChildView(active_pane_->panel());
  grid_layout->SetFlexForView(active_pane_->panel(), 1);
  window->AddChildView(grid);
  layout->SetFlexForView(grid, 1);

  OpenTab(first_url_.empty() ? "about:blank" : first_url_);
  manager_->OnWindowCreated(this);
  window->Show();
  if (first_url_.empty()) ShowPalette(/*new_tab=*/false);
}

void BrowserWindow::OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) {
  if (active) manager_->OnWindowActivated(this);
}

CefRefPtr<Tab> BrowserWindow::OpenTab(const std::string& url, Pane* pane, bool activate) {
  pane = pane ? pane : active_pane_;
  CefRefPtr<Tab> tab = manager_->CreateTab(url);
  pane->Add(tab, -1, activate);
  return tab;
}

void BrowserWindow::AdoptPopup(CefRefPtr<CefBrowser> opener, CefRefPtr<CefBrowserView> view, bool activate) {
  CefRefPtr<Tab> opener_tab;
  Pane* pane = Locate(opener, &opener_tab);
  pane = pane ? pane : active_pane_;
  pane->Add(manager_->AdoptTab(view), -1, activate);
}

Pane* BrowserWindow::Locate(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab) const {
  for (const std::unique_ptr<Pane>& pane : panes_) {
    if (CefRefPtr<Tab> found = pane->Find(browser)) {
      if (tab) *tab = found;
      return pane.get();
    }
  }
  return nullptr;
}

void BrowserWindow::CloseTab(CefRefPtr<Tab> tab) {
  if (CefRefPtr<CefBrowser> browser = tab->browser()) browser->GetHost()->CloseBrowser(false);
}

void BrowserWindow::OnTabClosed(CefRefPtr<CefBrowser> browser) {
  CefRefPtr<Tab> tab;
  Pane* pane = Locate(browser, &tab);
  if (!pane) return;
  pane->Remove(tab);
  bool any = false;
  for (const std::unique_ptr<Pane>& p : panes_) any = any || !p->tabs().empty();
  if (!any && window_) {
    closing_ = true;
    window_->Close();
  }
}

void BrowserWindow::OnTabChanged(CefRefPtr<CefBrowser> browser) {
  CefRefPtr<Tab> tab;
  Pane* pane = Locate(browser, &tab);
  if (!pane) return;
  pane->UpdateTabBar();
  if (tab == active_tab()) {
    top_bar_->Update();
    UpdateTitle();
  }
}

void BrowserWindow::OnActiveTabChanged(Pane* pane) {
  if (pane != active_pane_) return;
  top_bar_->Update();
  UpdateTitle();
}

void BrowserWindow::ShowPalette(bool new_tab, Pane* pane) {
  if (pane) active_pane_ = pane;
  manager_->ShowPalette(this, new_tab);
}

void BrowserWindow::UpdateTitle() {
  // The window's title names it in the Window menu and Mission Control.
  CefRefPtr<Tab> tab = active_tab();
  if (window_) window_->SetTitle(tab && !tab->title.empty() ? tab->title : "openp41ge explorer");
}

bool BrowserWindow::CanClose(CefRefPtr<CefWindow> window) {
  // Close every tab first (their pages may run unload handlers); the window
  // closes when the last one has (OnTabClosed).
  bool any = false;
  for (const std::unique_ptr<Pane>& pane : panes_) {
    for (const CefRefPtr<Tab>& tab : std::vector<CefRefPtr<Tab>>(pane->tabs())) {
      any = true;
      CloseTab(tab);
    }
  }
  closing_ = closing_ || any;
  return !any;
}

void BrowserWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  top_bar_->Detach();
  manager_->OnWindowDestroyed(this);
  panes_.clear();
  active_pane_ = nullptr;
  window_ = nullptr;
}
