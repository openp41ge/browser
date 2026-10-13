// Copyright (c) 2026 Richard Kielty. MIT License.

#include "pane.h"

#include <algorithm>

#include "include/views/cef_box_layout.h"
#include "include/views/cef_fill_layout.h"

#include "browser_manager.h"
#include "browser_window.h"

namespace {

}  // namespace

// A pane is the size the window's grid gives it (BrowserWindow::PaneSize),
// so the grid's layout puts it straight at that size.
class Pane::Delegate : public CefPanelDelegate {
 public:
  explicit Delegate(Pane* pane) : pane_(pane) {}
  void Detach() { pane_ = nullptr; }

  CefSize GetPreferredSize(CefRefPtr<CefView> view) override {
    return pane_ ? pane_->window()->PaneSize(pane_) : CefSize(1, 1);
  }
  CefSize GetMinimumSize(CefRefPtr<CefView> view) override { return CefSize(1, 1); }

 private:
  Pane* pane_;  // Null once the pane has gone.
  IMPLEMENT_REFCOUNTING(Delegate);
};

Pane::Pane(BrowserWindow* window) : window_(window), tab_bar_(new TabBar(this)) {}

Pane::~Pane() {
  tab_bar_->Detach();
  if (delegate_) delegate_->Detach();
}

CefRefPtr<CefPanel> Pane::panel() {
  if (!panel_) {
    delegate_ = new Delegate(this);
    panel_ = CefPanel::CreatePanel(delegate_);
    CefBoxLayoutSettings column;
    column.horizontal = false;
    CefRefPtr<CefBoxLayout> layout = panel_->SetToBoxLayout(column);
    content_ = CefPanel::CreatePanel(nullptr);
    content_->SetToFillLayout();
    panel_->AddChildView(tab_bar_->view());
    panel_->AddChildView(content_);
    layout->SetFlexForView(content_, 1);
    for (const CefRefPtr<Tab>& tab : tabs_) AddView(tab);
    ShowActive();
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
  AddView(tab);
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
  if (content_) content_->RemoveChildView(tab->view());
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

void Pane::RequestActivate(int id) {
  window_->SetActivePane(this);
  Activate(id);
}

int Pane::InsertIndexAt(int x) const {
  int index = 0;
  for (const auto& [id, middle] : tab_middles_) {
    if (middle < x) ++index;
  }
  return index;
}

int Pane::IndexOf(int id) const {
  for (size_t i = 0; i < tabs_.size(); ++i) {
    if (tabs_[i]->id() == id) return static_cast<int>(i);
  }
  return -1;
}

void Pane::RequestClose(int id) {
  if (CefRefPtr<Tab> tab = Find(id)) window_->CloseTab(tab);
}

void Pane::RequestNavigate(int id, const std::string& url) {
  CefRefPtr<Tab> tab = Find(id);
  CefRefPtr<CefBrowser> browser = tab ? tab->browser() : nullptr;
  if (!browser) return;
  if (History* history = window_->history()) history->AddTyped(url);
  browser->GetMainFrame()->LoadURL(url);
  RequestActivate(id);
  tab->view()->RequestFocus();
}

void Pane::EditAddress(int id) {
  tab_bar_->EditAddress(id);
  tab_bar_->view()->RequestFocus();
}

void Pane::RequestNewTab() {
  window_->SetActivePane(this);
  window_->NewTab(this);
}

void Pane::UpdateTabBar() {
  tab_bar_->Update();
}

// A tab's page joins the pane hidden (ShowActive shows the active one), and
// starts loading.
void Pane::AddView(CefRefPtr<Tab> tab) {
  if (!content_) return;
  tab->view()->SetVisible(false);
  content_->AddChildView(tab->view());
}

void Pane::ShowActive() {
  if (!content_) return;
  for (const CefRefPtr<Tab>& tab : tabs_) {
    if (tab != active_) tab->view()->SetVisible(false);
  }
  if (active_) {
    active_->view()->SetVisible(true);
    content_->Layout();
    active_->view()->RequestFocus();
  }
  window_->OnActiveTabChanged(this);
}
