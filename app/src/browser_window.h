// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_BROWSER_WINDOW_H_
#define OPENP41GE_EXPLORER_BROWSER_WINDOW_H_

#include <memory>
#include <string>
#include <vector>

#include "include/views/cef_window.h"

#include "divider_handles.h"
#include "drop_preview.h"
#include "focus_bar.h"
#include "grid_scrollbar.h"
#include "history.h"
#include "pane.h"
#include "suggestions_popup.h"
#include "tab_drag_image.h"
#include "top_bar.h"
#include "window_layout.h"

class BrowserManager;

// A browser window: the top bar above the pane grid. The grid is one row of
// panes (columns) with 1px divider lines between them, like openp41ge's
// (grab handles over the lines resize them: DividerHandles). Panes are at
// least 320px wide; when they don't fit, the grid scrolls sideways
// (GridScrollbar). Dragging a
// tab to a pane's left or right edge splits it, into a pane moves the tab
// there, and a pane whose last tab leaves goes. The window is frameless
// apart from macOS's traffic lights, which sit in the top bar.
//
// All of it is Alloy style: our UI in small web views (top bar, tab bars)
// and pages laid out beside them, never overlapping (layered views stop the
// views underneath getting clicks).
//
// A private window's pages use the private profile (see BrowserManager), and
// aren't recorded in History; its tabs move only to other private windows.
class BrowserWindow : public CefWindowDelegate {
 public:
  BrowserWindow(BrowserManager* manager, CefRect bounds, bool is_private, std::string first_url);
  // A window for a tab taken from another one.
  BrowserWindow(BrowserManager* manager, CefRect bounds, bool is_private, CefRefPtr<Tab> first_tab);
  // A window back as it was (closed, or open when the app last quit): each
  // pane's active tab loads, the others when they're first shown.
  BrowserWindow(BrowserManager* manager, WindowLayout layout);

  // Tells this window apart from others, including ones since closed.
  int id() const { return id_; }
  CefRefPtr<CefWindow> window() const { return window_; }
  BrowserManager* manager() const { return manager_; }
  bool is_private() const { return is_private_; }
  // Where this window's pages are recorded: none for a private window.
  History* history() const;
  Pane* active_pane() const { return active_pane_; }
  CefRefPtr<Tab> active_tab() const;
  CefRefPtr<CefBrowser> active_browser() const;

  // Opens `url` as a new tab in `pane` (default: the active pane), after its
  // active tab.
  CefRefPtr<Tab> OpenTab(const std::string& url, Pane* pane = nullptr, bool activate = true);
  // Brings back a closed tab: `url` at `index` in the pane at `pane_index`,
  // or in a new pane there if its pane went with it, and shows it.
  void ReopenTab(const std::string& url, int pane_index, int index, bool pane_closed);
  // Adds a page CEF created (a popup) as a tab beside `opener`'s.
  void AdoptPopup(CefRefPtr<CefBrowser> opener, CefRefPtr<CefBrowserView> view, bool activate);
  // The top bar shows the latest state (e.g. an update is available).
  void UpdateTopBar() { if (top_bar_) top_bar_->Update(); }
  // Every tab, pane by pane.
  std::vector<CefRefPtr<Tab>> tabs() const;
  // Where `browser`'s tab is, if it's one of this window's.
  Pane* Locate(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab = nullptr) const;

  // Asks the tab's page to close (it may run unload handlers first).
  void CloseTab(CefRefPtr<Tab> tab);
  // The page is closing: its tab goes, and the window if it was the last.
  void OnTabClosed(CefRefPtr<CefBrowser> browser);
  // Loads a tab brought back from the last session (Tab::Load).
  void LoadTab(CefRefPtr<Tab> tab);
  // A page's title, address, icon or loading state changed.
  void OnTabChanged(CefRefPtr<CefBrowser> browser);
  // Whether `pane`'s active tab is the focused tab: the window's active pane,
  // while the window is the active one.
  bool ShowsFocus(const Pane* pane) const;
  // A pane's active tab changed.
  void OnActiveTabChanged(Pane* pane);
  // Its tab bars showing each tab's picture (the previews button), or not.
  bool previews() const { return previews_; }
  void SetPreviews(bool shown);
  // Takes pictures of the tabs showing (each pane's active one), for their
  // previews: as they can only be taken while a page shows.
  void CapturePreviews();
  // Puts the focus bar over the focused tab's top edge (after its tab bar
  // reports where it is, or the panes move), or hides it.
  void UpdateFocusBar();
  // Opens a tab on the start page in `pane` (default: the active pane),
  // with its address focused, ready to type an address or a search.
  void NewTab(Pane* pane = nullptr);
  // The pane commands act on (Cmd+T, the top bar): the one last
  // clicked or focused.
  void SetActivePane(Pane* pane);

  // Divider handles (from DividerHandles), with the pointer on screen.
  void BeginResize(int divider, int screen_x);
  void ResizeTo(int screen_x);
  void EndResize();
  void EqualizePanes();

  // The suggestions under a tab whose address is being typed in `pane`'s
  // tab bar: `rows` with `selected` highlighted, under `tab` (in the tab
  // bar's coordinates), `width` wide. A click on a row goes back to that tab
  // bar.
  void ShowSuggestions(Pane* pane, CefRefPtr<CefListValue> rows, int selected, const CefRect& tab, int width);
  void HideSuggestions(Pane* pane);

  // The size the grid gives `pane` (its preferred size, for the grid's
  // layout).
  CefSize PaneSize(const Pane* pane) const;

  // A tab dragged from `source`'s tab bar, at (x, y) in that bar's
  // coordinates (from TabBar). A picture of it follows the pointer; it can
  // be dropped in this window, in another (it moves there), or on the
  // desktop (a new window for it).
  void DragTab(Pane* source, int tab_id, int x, int y);
  void DropTab(Pane* source, int tab_id, int x, int y);
  void CancelTabDrag();
  // While a tab from `source` (in this or another window) is dragged at
  // `screen`: show where it would land here.
  void ShowDropHints(Pane* source, int tab_id, const CefPoint& screen);
  void ClearDropHints();
  // Takes `tab`, dragged here from another window and dropped at `screen`.
  void AcceptTab(CefRefPtr<Tab> tab, const CefPoint& screen);

  // The window's panes and tabs, to bring it back (once it's closed, or
  // when the app next starts).
  WindowLayout Snapshot() const;

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowBoundsChanged(CefRefPtr<CefWindow> window, const CefRect& new_bounds) override;
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override;
  bool CanClose(CefRefPtr<CefWindow> window) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }
  bool IsFrameless(CefRefPtr<CefWindow> window) override { return true; }
  bool WithStandardWindowButtons(CefRefPtr<CefWindow> window) override { return true; }
  // Centres the traffic lights in the top bar.
  bool GetTitlebarHeight(CefRefPtr<CefWindow> window, float* titlebar_height) override {
    *titlebar_height = TopBar::kHeight;
    return true;
  }

 private:
  void UpdateTitle();

  // Where a dragged tab would land.
  struct DropTarget {
    enum class Kind { kNone, kTabBar, kPane, kSplitLeft, kSplitRight };
    Kind kind = Kind::kNone;
    Pane* pane = nullptr;
    int index = -1;       // kTabBar: where in the tab bar.
    CefRect preview;      // Screen area to highlight (kPane, kSplit*).
  };
  DropTarget FindDropTarget(Pane* source, int tab_id, const CefPoint& screen);
  // A dragged tab's point in screen coordinates.
  static CefPoint ScreenPoint(Pane* source, int x, int y);
  void EndTabDrag();
  // The window under `screen` that could take one of this window's tabs:
  // one of the same kind (private or not).
  BrowserWindow* DropWindowAt(const CefPoint& screen) const;
  // `tab` (in `pane`) has closed: it goes, and the window if it was the last.
  void OnTabClosed(Pane* pane, CefRefPtr<Tab> tab);
  // `tab` has left `pane` for another window: the pane goes if it's empty,
  // and the window if it was the last.
  void OnTabLeft(Pane* pane);
  // Rebuilds the grid's children (panes with 1px lines between) and lays it
  // out.
  void Relayout();
  // Places the panes: shared by weight, each at least the minimum width;
  // wider than the window, they scroll sideways under a scrollbar.
  void LayoutGrid();
  std::vector<int> PaneWidths(int content) const;
  // The panes' widths and height for the grid's current size.
  struct GridGeometry {
    std::vector<int> widths;
    int height = 0;
    int viewport = 0;  // The grid's width less the lines.
    int content = 0;   // The panes' total width (more than viewport: scrolled).
    bool overflow = false;
  };
  GridGeometry ComputeGeometry() const;
  // A new, empty pane at `index`; all panes then share the width equally.
  Pane* AddPane(int index);
  void RemovePane(Pane* pane);
  // RemovePane once the current event (e.g. a drop from that pane's own tab
  // bar) has been handled, if the pane is still there and empty.
  void RemovePaneSoon(Pane* pane);
  void MoveTab(CefRefPtr<Tab> tab, Pane* from, Pane* to, int index);
  int IndexOf(const Pane* pane) const;
  // Puts the divider handles over the divider lines (after any layout).
  void UpdateDividerHandles();


  BrowserManager* manager_;  // Lives as long as the app.
  const int id_;
  CefRect bounds_;
  const bool is_private_;
  std::string first_url_;
  CefRefPtr<Tab> first_tab_;
  WindowLayout restore_;  // A closed window being reopened (panes empty if not).
  CefRefPtr<CefWindow> window_;
  CefRefPtr<TopBar> top_bar_;
  CefRefPtr<CefPanel> grid_;
  std::vector<std::unique_ptr<Pane>> panes_;
  std::vector<CefRefPtr<CefPanel>> dividers_;  // The 1px lines between panes.
  std::unique_ptr<DividerHandles> divider_handles_;
  std::unique_ptr<GridScrollbar> scrollbar_;
  int scroll_offset_ = 0;
  Pane* active_pane_ = nullptr;
  Pane* marked_pane_ = nullptr;  // Whose tab bar shows the focused tab.
  std::unique_ptr<DropPreview> preview_;
  std::unique_ptr<FocusBar> focus_bar_;
  std::unique_ptr<TabDragImage> drag_image_;  // While one of this window's tabs is dragged.
  int drag_serial_ = 0;
  CefRefPtr<BrowserWindow> hint_window_;      // The window showing where it would land.
  CefRefPtr<SuggestionsPopup> suggestions_;
  Pane* suggesting_ = nullptr;  // Whose tab bar the suggestions are for.
  Pane* hinted_ = nullptr;  // The tab bar showing an insert hint.
  int resize_divider_ = -1;
  int resize_start_x_ = 0;
  std::vector<int> resize_widths_;  // Pane widths when the resize started.
  bool closing_ = false;
  bool window_active_ = false;  // The window has the keyboard.
  bool previews_ = false;

  IMPLEMENT_REFCOUNTING(BrowserWindow);
};

#endif  // OPENP41GE_EXPLORER_BROWSER_WINDOW_H_
