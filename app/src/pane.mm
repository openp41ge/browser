// Copyright (c) 2026 Richard Kielty. MIT License.

#include "pane.h"

#include <algorithm>

#include "include/views/cef_box_layout.h"
#include "include/views/cef_fill_layout.h"

#include "browser_window.h"

Pane::Pane(BrowserWindow* window) : window_(window), tab_bar_(new TabBar(this)) {}

Pane::~Pane() {
  tab_bar_->Detach();
}

CefRefPtr<CefPanel> Pane::panel() {
  if (!panel_) {
    panel_ = CefPanel::CreatePanel(nullptr);
    CefBoxLayoutSettings column;
    column.horizontal = false;
    CefRefPtr<CefBoxLayout> layout = panel_->SetToBoxLayout(column);
    content_ = CefPanel::CreatePanel(nullptr);
    content_->SetToFillLayout();
    panel_->AddChildView(tab_bar_->view());
    panel_->AddChildView(content_);
    layout->SetFlexForView(content_, 1);
  }
  return panel_;
}

CefRefPtr<Tab> Pane::Find(int id) const {
  for (const CefRefPtr<Tab>& tab : tabs_) {
    if (tab->id() == id) return tab;
  }
  return nullptr;
}

CefRefPtr<Tab> Pane::Find(CefRefPtr<CefBrowser> browser) const {
  for (const CefRefPtr<Tab>& tab : tabs_) {
    if (browser && tab->browser() && tab->browser()->IsSame(browser)) return tab;
  }
  return nullptr;
}

void Pane::Add(CefRefPtr<Tab> tab, int index, bool activate) {
  if (index < 0) {
    auto active = std::find(tabs_.begin(), tabs_.end(), active_);
    index = active == tabs_.end() ? static_cast<int>(tabs_.size()) : static_cast<int>(active - tabs_.begin()) + 1;
  }
  index = std::clamp(index, 0, static_cast<int>(tabs_.size()));
  tabs_.insert(tabs_.begin() + index, tab);
  if (activate || !active_) {
    active_ = tab;
    ShowActive();
  }
  UpdateTabBar();
}

void Pane::Remove(CefRefPtr<Tab> tab) {
  auto it = std::find(tabs_.begin(), tabs_.end(), tab);
  if (it == tabs_.end()) return;
  const size_t index = it - tabs_.begin();
  tabs_.erase(it);
  if (active_ == tab) {
    // The tab to its right, else to its left, as browsers do.
    active_ = tabs_.empty() ? nullptr : tabs_[std::min(index, tabs_.size() - 1)];
    ShowActive();
  }
  UpdateTabBar();
}

void Pane::Activate(int id) {
  CefRefPtr<Tab> tab = Find(id);
  if (!tab || tab == active_) return;
  active_ = tab;
  ShowActive();
  UpdateTabBar();
}

void Pane::ActivateRelative(int delta) {
  if (tabs_.empty()) return;
  auto it = std::find(tabs_.begin(), tabs_.end(), active_);
  const int count = static_cast<int>(tabs_.size());
  const int index = ((it == tabs_.end() ? 0 : static_cast<int>(it - tabs_.begin())) + delta % count + count) % count;
  Activate(tabs_[index]->id());
}

void Pane::Move(int id, int index) {
  CefRefPtr<Tab> tab = Find(id);
  if (!tab) return;
  tabs_.erase(std::find(tabs_.begin(), tabs_.end(), tab));
  index = std::clamp(index, 0, static_cast<int>(tabs_.size()));
  tabs_.insert(tabs_.begin() + index, tab);
  UpdateTabBar();
}

void Pane::RequestClose(int id) {
  if (CefRefPtr<Tab> tab = Find(id)) window_->CloseTab(tab);
}

void Pane::RequestNewTab() {
  window_->ShowPalette(/*new_tab=*/true, this);
}

void Pane::UpdateTabBar() {
  tab_bar_->Update();
}

void Pane::ShowActive() {
  if (!content_) return;
  content_->RemoveAllChildViews();
  if (active_) {
    content_->AddChildView(active_->view());
    content_->Layout();
    active_->view()->RequestFocus();
  }
  window_->OnActiveTabChanged(this);
}

