// Copyright (c) 2026 Richard Kielty. MIT License.

#include "pane.h"

#include <algorithm>
#include <chrono>

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
  if (find_bar_) find_bar_->Close();
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

void Pane::Leave(CefRefPtr<Tab> tab) {
  if (tab) tab->last_active = std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count();
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
    Leave(active_);
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
  if (content_ && tab->loaded()) content_->RemoveChildView(tab->view());
  if (active_ == tab) {
    // The tab to its right, else to its left, as browsers do.
    active_ = tabs_.empty() ? nullptr : tabs_[std::min(index, tabs_.size() - 1)];
    ShowActive();
  }
  UpdateTabBar();
}

void Pane::Restore(std::vector<CefRefPtr<Tab>> tabs, int active) {
  tabs_ = std::move(tabs);
  active_ = tabs_.empty() ? nullptr : tabs_[std::clamp(active, 0, static_cast<int>(tabs_.size()) - 1)];
  for (const CefRefPtr<Tab>& tab : tabs_) AddView(tab);
  ShowActive();
  UpdateTabBar();
}

void Pane::Activate(int id) {
  CefRefPtr<Tab> tab = Find(id);
  if (!tab || tab == active_) return;
  Leave(active_);
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

void Pane::RequestMute(int id) {
  CefRefPtr<Tab> tab = Find(id);
  CefRefPtr<CefBrowser> browser = tab ? tab->browser() : nullptr;
  if (!browser) return;
  tab->muted = !tab->muted;
  browser->GetHost()->SetAudioMuted(tab->muted);
  UpdateTabBar();
}

void Pane::RequestNavigate(int id, const std::string& url) {
  CefRefPtr<Tab> tab = Find(id);
  if (tab && !tab->loaded()) {
    // Not loaded yet: it loads this instead, as it's shown.
    if (History* history = window_->history()) history->AddTyped(url);
    tab->url = url;
    RequestActivate(id);
    return;
  }
  CefRefPtr<CefBrowser> browser = tab ? tab->browser() : nullptr;
  if (!browser) return;
  if (History* history = window_->history()) history->AddTyped(url);
  browser->GetMainFrame()->LoadURL(url);
  RequestActivate(id);
  tab->view()->RequestFocus();
}

void Pane::EditAddress(int id) {
  if (CefRefPtr<Tab> tab = Find(id)) tab->editing_address = true;
  tab_bar_->EditAddress(id);
  tab_bar_->view()->RequestFocus();
  // The keyboard comes to the window too: another of ours (the pop-out)
  // may have it.
  if (CefRefPtr<CefWindow> window = window_->window()) window->Activate();
}

void Pane::RequestNewTab() {
  window_->SetActivePane(this);
  window_->NewTab(this);
}

void Pane::UpdateTabBar() {
  tab_bar_->Update();
  // What it shows is kept for the next start.
  window_->manager()->SessionChanged();
}

// A tab's page joins the pane hidden (ShowActive shows the active one), and
// starts loading. (A tab not loaded yet has none.)
void Pane::AddView(CefRefPtr<Tab> tab) {
  if (!content_ || !tab->loaded()) return;
  tab->view()->SetVisible(false);
  content_->AddChildView(tab->view());
}

// A hidden page's media stops drawing video, even in the pop-out it's been
// moved to: so the tab a pop-out came from stays shown, under the active
// one, which covers it.
void Pane::ShowPages() {
  if (!content_) return;
  CefRefPtr<CefBrowser> popped = window_->manager()->popout()->source();
  for (const CefRefPtr<Tab>& tab : tabs_) {
    if (tab == active_ || !tab->loaded()) continue;
    tab->view()->SetVisible(popped && popped->IsSame(tab->browser()));
  }
  if (active_) {
    content_->ReorderChildView(active_->view(), -1);
    active_->view()->SetVisible(true);
    content_->Layout();
  }
}

void Pane::ShowActive() {
  if (!content_) return;
  // Brought back from the last session, it loads as it's first shown.
  if (active_ && !active_->loaded()) {
    window_->LoadTab(active_);
    AddView(active_);
  }
  ShowPages();
  if (active_) active_->view()->RequestFocus();
  UpdateFindBar();
  window_->OnActiveTabChanged(this);
}

// --- Find in page --------------------------------------------------------------

namespace {

// The room at the end of a page for the find row: an empty block after its
// body, as tall as the row, so its last lines can scroll clear of it.
constexpr char kAddFindRoom[] =
    "(() => {"
    "  if (document.getElementById('openp41ge-find-room')) return;"
    "  const room = document.createElement('div');"
    "  room.id = 'openp41ge-find-room';"
    "  room.setAttribute('aria-hidden', 'true');"
    "  room.style.cssText = 'display:block!important;height:35px!important;margin:0!important;"
    "padding:0!important;border:0!important;visibility:hidden!important;pointer-events:none!important';"
    "  document.documentElement.append(room);"
    "})()";
constexpr char kRemoveFindRoom[] = "document.getElementById('openp41ge-find-room')?.remove()";

}  // namespace

void Pane::OpenFind() {
  if (!active_ || !active_->browser()) return;
  if (!active_->finding) {
    active_->finding = true;
    SetFindRoom(active_, true);
  }
  if (!find_bar_) {
    find_bar_ = new FindBar(window_->window(), {
        .find = [this](const std::string& text, bool forward) { Find(text, forward); },
        .close = [this] { CloseFind(); },
    });
  }
  find_bar_->Open(FindBarPlacement(), active_->find_text);
  find_bar_->ShowResult(active_->find_count, active_->find_active);
}

void Pane::CloseFind() {
  if (!active_ || !active_->finding) return;
  active_->finding = false;
  if (CefRefPtr<CefBrowser> browser = active_->browser()) {
    // The current match stays selected, as in Chrome.
    browser->GetHost()->StopFinding(false);
  }
  SetFindRoom(active_, false);
  if (find_bar_) find_bar_->Hide();
  // The keyboard back to the page.
  if (CefRefPtr<CefWindow> window = window_->window()) window->Activate();
  active_->view()->RequestFocus();
}

void Pane::FindAgain(bool forward) {
  if (!CanFindAgain()) return;
  if (!active_->finding) OpenFind();
  Find(active_->find_text, forward);
}

bool Pane::CanFindAgain() const {
  return active_ && !active_->find_text.empty();
}

void Pane::Find(const std::string& text, bool forward) {
  if (!active_) return;
  CefRefPtr<CefBrowser> browser = active_->browser();
  if (!browser) return;
  active_->find_text = text;
  if (text.empty()) {
    browser->GetHost()->StopFinding(true);
    OnFindResult(active_, 0, 0);
    return;
  }
  // Always a "find next": CEF starts a new search itself when the text
  // changes, and only a find next makes a match the current one (the first
  // as it's typed, as in Chrome; a first request only counts them).
  browser->GetHost()->Find(text, forward, /*matchCase=*/false, /*findNext=*/true);
}

void Pane::OnFindResult(CefRefPtr<Tab> tab, int count, int active) {
  tab->find_count = count;
  tab->find_active = active;
  if (tab == active_ && find_bar_ && find_bar_->IsShown()) find_bar_->ShowResult(count, active);
}

void Pane::OnPageLoaded(CefRefPtr<Tab> tab) {
  if (tab->finding) SetFindRoom(tab, true);
}

void Pane::SetFindRoom(CefRefPtr<Tab> tab, bool room) {
  if (CefRefPtr<CefBrowser> browser = tab->browser()) {
    window_->manager()->devtools()->Evaluate(browser, room ? kAddFindRoom : kRemoveFindRoom, {});
  }
}

void Pane::UpdateFindBar() {
  if (!find_bar_) return;
  if (!active_ || !active_->finding || !content_) {
    if (find_bar_->IsShown()) find_bar_->Hide();
    return;
  }
  if (find_bar_->IsShown()) {
    find_bar_->MoveTo(FindBarPlacement());
  } else {
    find_bar_->Open(FindBarPlacement(), active_->find_text);
    find_bar_->ShowResult(active_->find_count, active_->find_active);
  }
}

// Over the bottom of the page, its width; and which of the window's edges
// that's on (a column in the middle of the grid is on neither side, and
// while the columns overflow there's a scrollbar under them).
FindBar::Placement Pane::FindBarPlacement() const {
  const CefRect page = content_ ? content_->GetBoundsInScreen() : CefRect();
  FindBar::Placement placement;
  placement.bounds = CefRect(page.x, page.y + page.height - FindBar::kHeight, page.width, FindBar::kHeight);
  if (CefRefPtr<CefWindow> window = window_->window()) {
    const CefRect frame = window->GetBoundsInScreen();
    placement.left = page.x <= frame.x;
    placement.right = page.x + page.width >= frame.x + frame.width;
    placement.bottom = page.y + page.height >= frame.y + frame.height;
  }
  return placement;
}
