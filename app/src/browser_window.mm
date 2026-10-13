// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_window.h"

#import <Cocoa/Cocoa.h>

#include <algorithm>

#include "include/base/cef_callback.h"
#include "include/cef_parser.h"
#include "include/views/cef_box_layout.h"
#include "include/wrapper/cef_closure_task.h"

#include "browser_manager.h"
#include "ui/ui_scheme.h"

namespace {

// Columns are at least this wide (a phone's width, so pages still lay out
// sensibly); with more columns than fit, the grid scrolls sideways.
constexpr int kMinPaneWidth = 320;
constexpr int kLineWidth = 1;
// Dropping within this far of a pane's edge splits it: 15% of the grid's
// width, at most a third of the pane.
constexpr double kSplitZone = 0.15;

bool Contains(const CefRect& r, int x, int y) {
  return x >= r.x && y >= r.y && x < r.x + r.width && y < r.y + r.height;
}

// openp41ge's --border-divider (app/ui/shared/theme.css), for the divider
// lines: the grey of the bars' borders and the active tabs, so they blend.
cef_color_t DividerColor() {
  NSAppearanceName match =
      [NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
  return [match isEqualToString:NSAppearanceNameDarkAqua] ? CefColorSetARGB(255, 0x2d, 0x2d, 0x2d)
                                                          : CefColorSetARGB(255, 0xe8, 0xe8, 0xe8);
}

// A divider line: 1px wide, as tall as the grid's panes.
class DividerDelegate : public CefPanelDelegate {
 public:
  explicit DividerDelegate(std::function<CefSize()> size) : size_(std::move(size)) {}
  CefSize GetPreferredSize(CefRefPtr<CefView> view) override { return size_(); }

 private:
  std::function<CefSize()> size_;
  IMPLEMENT_REFCOUNTING(DividerDelegate);
};

// The grid's panel: lays its panes out (BrowserWindow::LayoutGrid) whenever
// its size changes.
class GridDelegate : public CefPanelDelegate {
 public:
  explicit GridDelegate(std::function<void()> on_layout) : on_layout_(std::move(on_layout)) {}
  void OnLayoutChanged(CefRefPtr<CefView> view, const CefRect& new_bounds) override { on_layout_(); }

 private:
  std::function<void()> on_layout_;
  IMPLEMENT_REFCOUNTING(GridDelegate);
};

}  // namespace

BrowserWindow::BrowserWindow(BrowserManager* manager, CefRect bounds, bool is_private, std::string first_url)
    : manager_(manager),
      id_(manager->NewWindowId()),
      bounds_(bounds),
      is_private_(is_private),
      first_url_(std::move(first_url)),
      top_bar_(new TopBar(this)) {}

BrowserWindow::BrowserWindow(BrowserManager* manager, CefRect bounds, bool is_private, CefRefPtr<Tab> first_tab)
    : manager_(manager),
      id_(manager->NewWindowId()),
      bounds_(bounds),
      is_private_(is_private),
      first_tab_(first_tab),
      top_bar_(new TopBar(this)) {}

BrowserWindow::BrowserWindow(BrowserManager* manager, WindowLayout layout)
    : manager_(manager),
      id_(manager->NewWindowId()),
      bounds_(layout.bounds),
      is_private_(false),
      restore_(std::move(layout)),
      top_bar_(new TopBar(this)) {}

History* BrowserWindow::history() const {
  return is_private_ ? nullptr : manager_->history();
}

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

  // The grid: one row of panes, starting with one.
  // The grid lays its panes out itself (LayoutGrid): they can be wider than
  // the window, scrolled sideways.
  grid_ = CefPanel::CreatePanel(new GridDelegate([this] { LayoutGrid(); }));
  // A row of the panes and lines at their preferred sizes, which are the
  // sizes LayoutGrid gives them: so a page is only ever resized to its final
  // size. (A panel's default fill layout would first stretch every pane to
  // the whole grid, and each page would see that size too.) LayoutGrid then
  // only shifts them, while the grid is scrolled.
  CefBoxLayoutSettings row;
  row.horizontal = true;
  row.cross_axis_alignment = CEF_AXIS_ALIGNMENT_START;
  grid_->SetToBoxLayout(row);
  panes_.push_back(std::make_unique<Pane>(this));
  active_pane_ = panes_.back().get();
  window->AddChildView(grid_);
  layout->SetFlexForView(grid_, 1);
  divider_handles_ = std::make_unique<DividerHandles>(
      window, DividerHandles::Callbacks{
                  .begin = [this](int divider, int x) { BeginResize(divider, x); },
                  .move = [this](int x) { ResizeTo(x); },
                  .end = [this] { EndResize(); },
                  .reset = [this] { EqualizePanes(); },
              });
  scrollbar_ = std::make_unique<GridScrollbar>(window, [this](int offset) {
    scroll_offset_ = offset;
    LayoutGrid();
  });
  Relayout();
  preview_ = std::make_unique<DropPreview>(window);
  focus_bar_ = std::make_unique<FocusBar>(window);

  if (!restore_.panes.empty()) {
    // A closed window, back: its panes, their tabs, and the active ones.
    std::vector<CefRefPtr<Tab>> active;
    for (size_t i = 0; i < restore_.panes.size(); ++i) {
      Pane* pane = i == 0 ? active_pane_ : AddPane(static_cast<int>(i));
      const WindowLayout::PaneTabs& tabs = restore_.panes[i];
      for (size_t j = 0; j < tabs.urls.size(); ++j) {
        CefRefPtr<Tab> tab = OpenTab(tabs.urls[j], pane, /*activate=*/false);
        if (static_cast<int>(j) == tabs.active) pane->Activate(tab->id());
      }
    }
    Pane* pane = panes_[std::clamp<size_t>(restore_.active_pane, 0, panes_.size() - 1)].get();
    restore_ = WindowLayout();
    SetActivePane(pane);
    manager_->OnWindowCreated(this);
    window->Show();
    if (CefRefPtr<Tab> tab = active_tab()) tab->view()->RequestFocus();
  } else if (first_tab_) {
    // A tab dragged out of another window.
    active_pane_->Add(first_tab_, 0, /*activate=*/true);
    first_tab_ = nullptr;
    manager_->OnWindowCreated(this);
    window->Show();
    active_tab()->view()->RequestFocus();
  } else if (first_url_.empty()) {
    // The start page, with its address ready to type in.
    NewTab();
    manager_->OnWindowCreated(this);
    window->Show();
  } else {
    CefRefPtr<Tab> tab = OpenTab(first_url_);
    manager_->OnWindowCreated(this);
    window->Show();
    tab->view()->RequestFocus();
  }
}

void BrowserWindow::OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) {
  window_active_ = active;
  if (active) manager_->OnWindowActivated(this);
  // The focused tab's line shows only in the window that has the keyboard;
  // the active pane (and so the tab it returns to) is kept meanwhile.
  if (IndexOf(marked_pane_) >= 0) marked_pane_->UpdateTabBar();
  UpdateFocusBar();
}

bool BrowserWindow::ShowsFocus(const Pane* pane) const {
  return window_active_ && pane == active_pane_;
}

CefRefPtr<Tab> BrowserWindow::OpenTab(const std::string& url, Pane* pane, bool activate) {
  pane = pane ? pane : active_pane_;
  CefRefPtr<Tab> tab = manager_->CreateTab(url, is_private_);
  pane->Add(tab, -1, activate);
  return tab;
}

void BrowserWindow::ReopenTab(const std::string& url, int pane_index, int index, bool pane_closed) {
  pane_index = std::clamp(pane_index, 0, static_cast<int>(panes_.size()) - (pane_closed ? 0 : 1));
  Pane* pane = pane_closed ? AddPane(pane_index) : panes_[pane_index].get();
  CefRefPtr<Tab> tab = manager_->CreateTab(url, is_private_);
  pane->Add(tab, index, /*activate=*/true);
  SetActivePane(pane);
  if (window_) window_->Activate();
  tab->view()->RequestFocus();
}

WindowLayout BrowserWindow::Snapshot() const {
  WindowLayout layout;
  layout.bounds = window_ ? window_->GetBounds() : bounds_;
  for (const std::unique_ptr<Pane>& pane : panes_) {
    WindowLayout::PaneTabs tabs;
    for (const CefRefPtr<Tab>& tab : pane->tabs()) {
      if (tab == pane->active_tab()) tabs.active = static_cast<int>(tabs.urls.size());
      tabs.urls.push_back(tab->url);
    }
    if (pane.get() == active_pane_) layout.active_pane = static_cast<int>(layout.panes.size());
    if (!tabs.urls.empty()) layout.panes.push_back(std::move(tabs));
  }
  return layout;
}

void BrowserWindow::AdoptPopup(CefRefPtr<CefBrowser> opener, CefRefPtr<CefBrowserView> view, bool activate) {
  CefRefPtr<Tab> opener_tab;
  Pane* pane = Locate(opener, &opener_tab);
  pane = pane ? pane : active_pane_;
  pane->Add(manager_->AdoptTab(view), -1, activate);
}

std::vector<CefRefPtr<Tab>> BrowserWindow::tabs() const {
  std::vector<CefRefPtr<Tab>> all;
  for (const std::unique_ptr<Pane>& pane : panes_) all.insert(all.end(), pane->tabs().begin(), pane->tabs().end());
  return all;
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
  // A tab closed on its own (not with its window) can be reopened.
  if (!closing_ && !is_private_) {
    manager_->RememberClosedTab(this, tab->url, IndexOf(pane), pane->IndexOf(tab->id()),
                                pane->tabs().size() == 1 && panes_.size() > 1);
  }
  pane->Remove(tab);
  if (pane->tabs().empty() && panes_.size() > 1) RemovePane(pane);
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
  // The active pane's tab bar marks its active tab (the focused tab).
  if (marked_pane_ != active_pane_) {
    if (IndexOf(marked_pane_) >= 0) marked_pane_->UpdateTabBar();
    marked_pane_ = active_pane_;
    if (marked_pane_) marked_pane_->UpdateTabBar();
  }
  UpdateFocusBar();
  if (pane != active_pane_) return;
  top_bar_->Update();
  UpdateTitle();
}

void BrowserWindow::UpdateFocusBar() {
  if (!focus_bar_) return;
  const CefRange range = active_pane_ && IndexOf(active_pane_) >= 0 ? active_pane_->focus_bar() : CefRange();
  CefPoint from(range.from, 0);
  if (!window_active_ || closing_ || range.to <= range.from ||
      !active_pane_->tab_bar_view()->ConvertPointToScreen(from)) {
    focus_bar_->Hide();
    return;
  }
  // Only over the grid in view (a pane can be scrolled partly out of it).
  const CefRect grid = grid_->GetBoundsInScreen();
  const int left = std::max(from.x, grid.x);
  const int right = std::min(from.x + static_cast<int>(range.to - range.from), grid.x + grid.width);
  if (right <= left) {
    focus_bar_->Hide();
    return;
  }
  // Centred on the tab's top edge as it shows: the top bar's 1px divider
  // above the tab bar is the active tab's colour (--border-divider), so the
  // tab looks to start there.
  constexpr int kTopBarDivider = 1;
  focus_bar_->Show(left, from.y - kTopBarDivider, right - left);
}

void BrowserWindow::NewTab(Pane* pane) {
  pane = pane ? pane : active_pane_;
  CefRefPtr<Tab> tab = OpenTab(ui_scheme::kStartUrl, pane);
  pane->EditAddress(tab->id());
}

void BrowserWindow::SetActivePane(Pane* pane) {
  if (!pane || pane == active_pane_) return;
  active_pane_ = pane;
  OnActiveTabChanged(pane);
}

// --- Suggestions -------------------------------------------------------------

void BrowserWindow::ShowSuggestions(Pane* pane,
                                    CefRefPtr<CefListValue> rows,
                                    int selected,
                                    const CefRect& tab,
                                    int width) {
  if (!window_ || closing_) return;
  CefPoint origin(tab.x, tab.y);
  if (!pane->tab_bar_view()->ConvertPointToScreen(origin)) return;
  if (!suggestions_) {
    suggestions_ = new SuggestionsPopup(
        window_,
        [this](int index) {
          if (IndexOf(suggesting_) >= 0) suggesting_->PickSuggestion(index);
        },
        [this](int index) {
          if (IndexOf(suggesting_) >= 0) suggesting_->RemoveSuggestion(index);
        });
  }
  suggesting_ = pane;
  suggestions_->Show(rows, selected, CefRect(origin.x, origin.y, tab.width, tab.height), width);
}

void BrowserWindow::HideSuggestions(Pane* pane) {
  if (suggestions_ && suggesting_ == pane) suggestions_->Hide();
}

// --- Grid -------------------------------------------------------------------

int BrowserWindow::IndexOf(const Pane* pane) const {
  for (size_t i = 0; i < panes_.size(); ++i) {
    if (panes_[i].get() == pane) return static_cast<int>(i);
  }
  return -1;
}

void BrowserWindow::Relayout() {
  if (!grid_) return;
  grid_->RemoveAllChildViews();
  while (dividers_.size() + 1 < panes_.size()) {
    // A 1px line in the border colour, like a column's border in openp41ge.
    dividers_.push_back(CefPanel::CreatePanel(new DividerDelegate([this] {
      return CefSize(kLineWidth, ComputeGeometry().height);
    })));
  }
  while (dividers_.size() + 1 > panes_.size() && !dividers_.empty()) dividers_.pop_back();
  for (size_t i = 0; i < panes_.size(); ++i) {
    if (i > 0) {
      dividers_[i - 1]->SetBackgroundColor(DividerColor());
      grid_->AddChildView(dividers_[i - 1]);
    }
    grid_->AddChildView(panes_[i]->panel());
  }
  LayoutGrid();
}

std::vector<int> BrowserWindow::PaneWidths(int content) const {
  // Shared by weight, then any pane under the minimum is raised to it and
  // the others give up the difference in proportion.
  std::vector<int> widths(panes_.size(), 0);
  std::vector<bool> fixed(panes_.size(), false);
  int left = content;
  for (bool changed = true; changed;) {
    changed = false;
    double weights = 0;
    for (size_t i = 0; i < panes_.size(); ++i) {
      if (!fixed[i]) weights += std::max(1, panes_[i]->weight);
    }
    for (size_t i = 0; i < panes_.size(); ++i) {
      if (fixed[i]) continue;
      widths[i] = static_cast<int>(left * std::max(1, panes_[i]->weight) / weights);
      if (widths[i] < kMinPaneWidth) {
        widths[i] = kMinPaneWidth;
        fixed[i] = true;
        left -= kMinPaneWidth;
        changed = true;
        break;
      }
    }
  }
  // Rounding: the last pane takes what's left.
  int used = 0;
  for (size_t i = 0; i + 1 < widths.size(); ++i) used += widths[i];
  if (!widths.empty()) widths.back() = std::max(kMinPaneWidth, content - used);
  return widths;
}

BrowserWindow::GridGeometry BrowserWindow::ComputeGeometry() const {
  GridGeometry geometry;
  if (!grid_ || panes_.empty()) return geometry;
  const CefRect bounds = grid_->GetBounds();
  const int n = static_cast<int>(panes_.size());
  geometry.viewport = bounds.width - (n - 1) * kLineWidth;
  geometry.content = std::max(geometry.viewport, n * kMinPaneWidth);
  geometry.overflow = geometry.content > geometry.viewport;
  // While the panes overflow, a scrollbar strip runs under them.
  geometry.height = bounds.height - (geometry.overflow ? GridScrollbar::kHeight : 0);
  geometry.widths = PaneWidths(geometry.content);
  return geometry;
}

CefSize BrowserWindow::PaneSize(const Pane* pane) const {
  const GridGeometry geometry = ComputeGeometry();
  const int index = IndexOf(pane);
  if (index < 0 || index >= static_cast<int>(geometry.widths.size())) return CefSize(1, 1);
  return CefSize(geometry.widths[index], std::max(1, geometry.height));
}

void BrowserWindow::LayoutGrid() {
  if (!grid_ || panes_.empty()) return;
  const CefRect bounds = grid_->GetBounds();
  const int n = static_cast<int>(panes_.size());
  const GridGeometry geometry = ComputeGeometry();
  const int viewport = geometry.viewport;
  const int content = geometry.content;
  const bool overflow = geometry.overflow;
  const int height = geometry.height;
  scroll_offset_ = std::clamp(scroll_offset_, 0, content - viewport);

  const std::vector<int>& widths = geometry.widths;
  int x = -scroll_offset_;
  for (int i = 0; i < n; ++i) {
    if (i > 0) {
      dividers_[i - 1]->SetBounds(CefRect(x, 0, kLineWidth, height));
      x += kLineWidth;
    }
    panes_[i]->panel()->SetBounds(CefRect(x, 0, widths[i], height));
    x += widths[i];
  }

  if (overflow) {
    const CefRect screen = grid_->GetBoundsInScreen();
    scrollbar_->Update(CefRect(screen.x, screen.y + height, screen.width, GridScrollbar::kHeight),
                       content + (n - 1) * kLineWidth, bounds.width, scroll_offset_);
  } else {
    scrollbar_->Hide();
  }
  UpdateDividerHandles();
  UpdateFocusBar();
  for (const std::unique_ptr<Pane>& pane : panes_) pane->UpdateFindBar();
}

void BrowserWindow::UpdateDividerHandles() {
  if (!divider_handles_ || !grid_) return;
  // Only the lines in view (the grid may be scrolled).
  const CefRect grid = grid_->GetBoundsInScreen();
  std::vector<CefRect> lines;
  for (const CefRefPtr<CefPanel>& line : dividers_) {
    if (!line->GetParentView()) continue;
    const CefRect r = line->GetBoundsInScreen();
    if (r.x > grid.x && r.x < grid.x + grid.width - 1) lines.push_back(r);
  }
  divider_handles_->Update(lines);
}

Pane* BrowserWindow::AddPane(int index) {
  // A new pane: all panes share the width equally again.
  for (const std::unique_ptr<Pane>& pane : panes_) pane->weight = 1000;
  auto pane = std::make_unique<Pane>(this);
  Pane* added = pane.get();
  panes_.insert(panes_.begin() + std::clamp(index, 0, static_cast<int>(panes_.size())), std::move(pane));
  Relayout();
  return added;
}

void BrowserWindow::RemovePane(Pane* pane) {
  const int index = IndexOf(pane);
  if (index < 0) return;
  // Its width goes to the others, in proportion to theirs (their weights
  // stay as they are).
  std::unique_ptr<Pane> removed = std::move(panes_[index]);
  panes_.erase(panes_.begin() + index);
  if (active_pane_ == pane) {
    active_pane_ = panes_.empty() ? nullptr : panes_[std::min<size_t>(index, panes_.size() - 1)].get();
  }
  if (hinted_ == pane) hinted_ = nullptr;
  Relayout();
  if (active_pane_) OnActiveTabChanged(active_pane_);
}

void BrowserWindow::MoveTab(CefRefPtr<Tab> tab, Pane* from, Pane* to, int index) {
  from->Remove(tab);
  to->Add(tab, index, /*activate=*/true);
  active_pane_ = to;
  OnActiveTabChanged(to);
  if (from != to && from->tabs().empty()) RemovePaneSoon(from);
}

void BrowserWindow::RemovePaneSoon(Pane* pane) {
  CefRefPtr<BrowserWindow> self(this);
  CefPostTask(TID_UI, base::BindOnce(
                          [](CefRefPtr<BrowserWindow> self, Pane* pane) {
                            const int index = self->IndexOf(pane);
                            if (index >= 0 && pane->tabs().empty() && self->panes_.size() > 1) self->RemovePane(pane);
                          },
                          self, pane));
}

void BrowserWindow::BeginResize(int divider, int screen_x) {
  if (divider < 0 || divider + 1 >= static_cast<int>(panes_.size())) return;
  resize_divider_ = divider;
  resize_start_x_ = screen_x;
  resize_widths_.clear();
  for (const std::unique_ptr<Pane>& pane : panes_) resize_widths_.push_back(pane->panel()->GetBounds().width);
}

void BrowserWindow::ResizeTo(int screen_x) {
  if (resize_divider_ < 0 || resize_widths_.size() != panes_.size()) return;
  const int dx = screen_x - resize_start_x_;
  const size_t left = resize_divider_;
  const size_t right = left + 1;
  const int total = resize_widths_[left] + resize_widths_[right];
  const int min = std::min(kMinPaneWidth, total / 2);
  const int left_width = std::clamp(resize_widths_[left] + dx, min, total - min);
  for (size_t i = 0; i < panes_.size(); ++i) {
    panes_[i]->weight = i == left ? left_width : i == right ? total - left_width : resize_widths_[i];
  }
  LayoutGrid();
}

void BrowserWindow::EndResize() {
  resize_divider_ = -1;
  resize_widths_.clear();
}

void BrowserWindow::EqualizePanes() {
  for (const std::unique_ptr<Pane>& pane : panes_) pane->weight = 1000;
  LayoutGrid();
}

BrowserWindow::DropTarget BrowserWindow::FindDropTarget(Pane* source, int tab_id, const CefPoint& screen) {
  const int px = screen.x;
  const int py = screen.y;
  const CefRect grid = grid_->GetBoundsInScreen();
  DropTarget target;
  for (const std::unique_ptr<Pane>& p : panes_) {
    Pane* pane = p.get();
    // Over a tab bar: into it at that point (a move to where it already is
    // isn't a move).
    const CefRect bar = pane->tab_bar_view()->GetBoundsInScreen();
    if (Contains(bar, px, py)) {
      const int index = pane->InsertIndexAt(px - bar.x);
      const int from = pane == source ? pane->IndexOf(tab_id) : -1;
      if (from >= 0 && (index == from || index == from + 1)) return target;
      target.kind = DropTarget::Kind::kTabBar;
      target.pane = pane;
      target.index = index;
      return target;
    }
    // Over a pane: near its left or right edge splits it, elsewhere moves
    // the tab into it.
    const CefRect r = pane->panel()->GetBoundsInScreen();
    if (!Contains(r, px, py)) continue;
    const int zone = static_cast<int>(std::min(grid.width * kSplitZone, r.width / 3.0));
    const bool alone = pane == source && pane->tabs().size() == 1;
    target.pane = pane;
    if (px - r.x < zone && !alone) {
      target.kind = DropTarget::Kind::kSplitLeft;
      target.preview = CefRect(r.x, r.y, r.width / 2, r.height);
    } else if (r.x + r.width - px <= zone && !alone) {
      target.kind = DropTarget::Kind::kSplitRight;
      target.preview = CefRect(r.x + r.width - r.width / 2, r.y, r.width / 2, r.height);
    } else if (pane != source) {
      target.kind = DropTarget::Kind::kPane;
      target.preview = r;
    } else {
      target.pane = nullptr;
    }
    return target;
  }
  return target;  // Outside the grid.
}

CefPoint BrowserWindow::ScreenPoint(Pane* source, int x, int y) {
  const CefRect origin = source->tab_bar_view()->GetBoundsInScreen();
  return CefPoint(origin.x + x, origin.y + y);
}

void BrowserWindow::ClearDropHints() {
  if (hinted_) hinted_->ShowInsertHint(-1);
  hinted_ = nullptr;
  if (preview_) preview_->Hide();
}

void BrowserWindow::ShowDropHints(Pane* source, int tab_id, const CefPoint& screen) {
  const DropTarget target = FindDropTarget(source, tab_id, screen);
  if (hinted_ && hinted_ != target.pane) hinted_->ShowInsertHint(-1);
  hinted_ = nullptr;
  if (target.kind == DropTarget::Kind::kTabBar) {
    target.pane->ShowInsertHint(target.index);
    hinted_ = target.pane;
    preview_->Hide();
  } else if (target.kind == DropTarget::Kind::kNone) {
    preview_->Hide();
  } else {
    preview_->Show(target.preview);
  }
}

void BrowserWindow::DragTab(Pane* source, int tab_id, int x, int y) {
  const CefPoint screen = ScreenPoint(source, x, y);
  if (!drag_image_) {
    // The drag has begun: a picture of the tab, and its page once captured.
    CefRefPtr<Tab> tab = source->Find(tab_id);
    if (!tab) return;
    drag_image_ = std::make_unique<TabDragImage>(tab->title.empty() ? tab->url : tab->title);
    const int serial = ++drag_serial_;
    CefRefPtr<CefBrowser> browser = tab->browser();
    const CefRect bounds = tab->view()->GetBounds();
    if (browser && bounds.width > 0 && bounds.height > 0) {
      CefRefPtr<CefDictionaryValue> clip = CefDictionaryValue::Create();
      clip->SetDouble("x", 0);
      clip->SetDouble("y", 0);
      clip->SetDouble("width", bounds.width);
      clip->SetDouble("height", bounds.height);
      clip->SetDouble("scale", 0.5);
      CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
      params->SetString("format", "jpeg");
      params->SetInt("quality", 75);
      params->SetDictionary("clip", clip);
      CefRefPtr<BrowserWindow> self(this);
      manager_->devtools()->Call(browser, "Page.captureScreenshot", params,
                                 [self, serial](CefRefPtr<CefDictionaryValue> result) {
                                   if (!result || !self->drag_image_ || self->drag_serial_ != serial) return;
                                   CefRefPtr<CefBinaryValue> data = CefBase64Decode(result->GetString("data"));
                                   if (!data || data->GetSize() == 0) return;
                                   std::string bytes(data->GetSize(), '\0');
                                   data->GetData(bytes.data(), bytes.size(), 0);
                                   self->drag_image_->SetSnapshot(bytes);
                                 });
    }
  }
  drag_image_->MoveTo(screen);
  // Where it would land: whichever of the browser's windows is under the
  // pointer (none: a new window).
  CefRefPtr<BrowserWindow> target = DropWindowAt(screen);
  if (hint_window_ && hint_window_ != target) hint_window_->ClearDropHints();
  hint_window_ = target;
  if (target) target->ShowDropHints(source, tab_id, screen);
}

BrowserWindow* BrowserWindow::DropWindowAt(const CefPoint& screen) const {
  BrowserWindow* window = manager_->WindowAt(screen);
  return window && window->is_private() == is_private_ ? window : nullptr;
}

void BrowserWindow::EndTabDrag() {
  drag_image_.reset();
  if (hint_window_) hint_window_->ClearDropHints();
  hint_window_ = nullptr;
  ClearDropHints();
}

void BrowserWindow::DropTab(Pane* source, int tab_id, int x, int y) {
  const CefPoint screen = ScreenPoint(source, x, y);
  const bool dragged = drag_image_ != nullptr;
  EndTabDrag();
  CefRefPtr<Tab> tab = source->Find(tab_id);
  if (!tab || !dragged) return;
  BrowserWindow* target_window = manager_->WindowAt(screen);
  // A window of the other kind (private or not) can't take it: it stays.
  if (target_window && target_window->is_private() != is_private_) return;
  if (target_window != this) {
    // To another window, or onto the desktop: a new window, the same size,
    // with the tab under the pointer.
    source->Remove(tab);
    if (target_window) {
      target_window->AcceptTab(tab, screen);
    } else {
      const CefRect frame = window_->GetBounds();
      const CefRect bounds(screen.x - TabDragImage::kGrabX, screen.y - TopBar::kHeight - TabDragImage::kGrabY,
                           frame.width, frame.height);
      manager_->OpenWindowWithTab(tab, bounds, is_private_);
    }
    OnTabLeft(source);
    return;
  }
  const DropTarget target = FindDropTarget(source, tab_id, screen);
  switch (target.kind) {
    case DropTarget::Kind::kNone:
      return;
    case DropTarget::Kind::kTabBar:
      if (target.pane == source) {
        const int from = source->IndexOf(tab_id);
        source->Move(tab_id, target.index > from ? target.index - 1 : target.index);
      } else {
        MoveTab(tab, source, target.pane, target.index);
      }
      return;
    case DropTarget::Kind::kPane:
      MoveTab(tab, source, target.pane, -1);
      return;
    case DropTarget::Kind::kSplitLeft:
    case DropTarget::Kind::kSplitRight: {
      const int index = IndexOf(target.pane) + (target.kind == DropTarget::Kind::kSplitRight ? 1 : 0);
      MoveTab(tab, source, AddPane(index), 0);
      return;
    }
  }
}

void BrowserWindow::AcceptTab(CefRefPtr<Tab> tab, const CefPoint& screen) {
  const DropTarget target = FindDropTarget(nullptr, tab->id(), screen);
  Pane* pane = active_pane_;
  int index = -1;
  switch (target.kind) {
    case DropTarget::Kind::kTabBar:
      pane = target.pane;
      index = target.index;
      break;
    case DropTarget::Kind::kPane:
      pane = target.pane;
      break;
    case DropTarget::Kind::kSplitLeft:
    case DropTarget::Kind::kSplitRight:
      pane = AddPane(IndexOf(target.pane) + (target.kind == DropTarget::Kind::kSplitRight ? 1 : 0));
      index = 0;
      break;
    case DropTarget::Kind::kNone:  // The top bar, say: the active pane.
      break;
  }
  pane->Add(tab, index, /*activate=*/true);
  active_pane_ = pane;
  OnActiveTabChanged(pane);
  if (window_) window_->Activate();
  tab->view()->RequestFocus();
}

void BrowserWindow::OnTabLeft(Pane* pane) {
  if (!pane->tabs().empty()) return;
  if (panes_.size() > 1) {
    RemovePaneSoon(pane);
    return;
  }
  // The window's last tab: the window goes, once the drop has been handled
  // (it came from this window's own tab bar).
  CefRefPtr<BrowserWindow> self(this);
  CefPostTask(TID_UI, base::BindOnce(
                          [](CefRefPtr<BrowserWindow> self) {
                            if (self->window_ && self->active_tab() == nullptr) self->window_->Close();
                          },
                          self));
}

void BrowserWindow::CancelTabDrag() {
  EndTabDrag();
}

void BrowserWindow::UpdateTitle() {
  // The window's title names it in the Window menu and Mission Control.
  // A development build's say so (its Dock name is the engine's, "Chromium"),
  // as the openp41ge app's do: "openp41ge browser development — <page>".
  CefRefPtr<Tab> tab = active_tab();
#if defined(EXPLORER_DEV_BUILD)
  constexpr char kDevName[] = "openp41ge browser development";
  const std::string title = tab && !tab->title.empty() ? std::string(kDevName) + " — " + tab->title : kDevName;
#else
  const std::string title = tab && !tab->title.empty() ? tab->title : "openp41ge explorer";
#endif
  if (window_) window_->SetTitle(is_private_ ? title + " (Private)" : title);
}

bool BrowserWindow::CanClose(CefRefPtr<CefWindow> window) {
  if (suggestions_) suggestions_->Close();
  // Close every tab first (their pages may run unload handlers); the window
  // closes when the last one has (OnTabClosed). Collected first: closing a
  // pane's last tab removes the pane.
  std::vector<CefRefPtr<Tab>> tabs;
  for (const std::unique_ptr<Pane>& pane : panes_) {
    tabs.insert(tabs.end(), pane->tabs().begin(), pane->tabs().end());
  }
  // A window closed with its tabs can be reopened, all of them.
  if (!closing_ && !tabs.empty() && !is_private_) manager_->RememberClosedWindow(Snapshot());
  closing_ = closing_ || !tabs.empty();
  for (const CefRefPtr<Tab>& tab : tabs) CloseTab(tab);
  return tabs.empty();
}

void BrowserWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  top_bar_->Detach();
  divider_handles_.reset();
  scrollbar_.reset();
  preview_.reset();
  focus_bar_.reset();
  if (suggestions_) suggestions_->Close();
  suggestions_ = nullptr;
  suggesting_ = nullptr;
  // The panes' find rows start closing, before the app might quit.
  panes_.clear();
  manager_->OnWindowDestroyed(this);
  active_pane_ = nullptr;
  window_ = nullptr;
}
