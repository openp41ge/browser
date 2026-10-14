// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_manager.h"

#import <Cocoa/Cocoa.h>

#include <algorithm>
#include <set>

#include "include/base/cef_callback.h"
#include "include/cef_app.h"
#include "include/cef_command_line.h"
#include "include/cef_parser.h"
#include "include/cef_request_context.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

#include "include/views/cef_display.h"

#include "session.h"
#include "tab_previews.h"
#include "ui/ui_live_reload.h"
#include "updater.h"
#include "extensions/extension_router.h"
#include "ui/ui_scheme.h"
#include "ui/ui_view.h"

namespace {

BrowserManager* g_manager = nullptr;

// Key read by the renderer (renderer_app.cc).
constexpr char kInitScriptKey[] = "openp41ge.init_script";
// Where a page waits for extensions' scripts (CreatePageView), and for how
// long at most.
constexpr char kBlankUrl[] = "about:blank";
constexpr int kExtensionsWaitMs = 2000;

// The browser keeps its own history (History); Chromium would keep another
// (<profile>/History, with its favicons and top sites) that nothing reads,
// and that forgetting a page in ours wouldn't touch.
void DisableChromiumHistory(CefRefPtr<CefRequestContext> context) {
  constexpr char kSavingDisabled[] = "history.saving_disabled";
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetBool(true);
  CefString error;
  if (!context->SetPreference(kSavingDisabled, value, error)) {
    LOG(ERROR) << "Could not set " << kSavingDisabled << ": " << error.ToString();
  }
}

// Every page: Alloy style. Popups become tabs (see OnPopupViewCreated);
// dev tools get CEF's own window.
class PageViewDelegate : public CefBrowserViewDelegate {
 public:
  explicit PageViewDelegate(BrowserManager* manager) : manager_(manager) {}

  cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_ALLOY; }
  CefRefPtr<CefBrowserViewDelegate> GetDelegateForPopupBrowserView(CefRefPtr<CefBrowserView> view,
                                                                   const CefBrowserSettings& settings,
                                                                   CefRefPtr<CefClient> client,
                                                                   bool is_devtools) override {
    return this;
  }
  bool OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> view,
                                 CefRefPtr<CefBrowserView> popup_view,
                                 bool is_devtools) override {
    if (is_devtools) return false;
    manager_->OnPopupViewCreated(view, popup_view);
    return true;
  }

 private:
  BrowserManager* manager_;  // Lives as long as the app.
  IMPLEMENT_REFCOUNTING(PageViewDelegate);
};

}  // namespace

BrowserManager::BrowserManager()
    : devtools_(new DevToolsClient()),
      popout_(new PopoutController(devtools_, this)),
      extensions_(std::make_unique<ExtensionManager>(
          devtools_,
          CefRequestContext::GetGlobalContext()->GetCachePath(),
          [this](CefRefPtr<CefBrowser> opener, const std::string& url) {
            OpenLink(opener, url, CEF_WOD_NEW_FOREGROUND_TAB);
          })),
      extension_router_(CefMessageRouterBrowserSide::Create(extension_router::Config())),
      view_delegate_(new PageViewDelegate(this)),
      history_(std::make_unique<History>(CefRequestContext::GetGlobalContext()->GetCachePath())) {
  DCHECK(!g_manager);
  g_manager = this;
  DisableChromiumHistory(CefRequestContext::GetGlobalContext());
  tab_previews::Init(CefRequestContext::GetGlobalContext()->GetCachePath());
  // Extensions in local folders, for this run:
  // --extension-folder=<folder>[:<folder>…].
  const std::string folders = CefCommandLine::GetGlobalCommandLine()->GetSwitchValue("extension-folder");
  std::vector<std::string> list;
  for (size_t start = 0; start < folders.size();) {
    const size_t end = std::min(folders.find(':', start), folders.size());
    if (end > start) list.push_back(folders.substr(start, end - start));
    start = end + 1;
  }
  extensions_->LoadFolders(list);
  extension_router_->AddHandler(extensions_.get(), /*first=*/false);
  // A development build's UI, as it's edited (ui_live_reload.h).
  ui_live_reload::Watch([this] { ReloadUi(); });
  // An update waiting for the user shows in every window's top bar.
  updater::SetObserver([this] {
    for (const CefRefPtr<BrowserWindow>& window : windows_) window->UpdateTopBar();
  });
}

// About openp41ge explorer: its tab if one's open in this window (as Chrome
// does), else a new one; a new window if there's none.
void BrowserManager::ShowAbout() {
  if (!current_) {
    OpenWindow(ui_scheme::kAboutUrl);
    return;
  }
  for (const CefRefPtr<Tab>& tab : current_->tabs()) {
    CefRefPtr<CefBrowser> page = tab->browser();
    if (!page || tab->url.rfind(ui_scheme::kAboutUrl, 0) != 0) continue;
    if (Pane* pane = current_->Locate(page)) {
      pane->RequestActivate(tab->id());
      tab->view()->RequestFocus();
      return;
    }
  }
  CefRefPtr<Tab> tab = current_->OpenTab(ui_scheme::kAboutUrl);
  tab->view()->RequestFocus();
}

void BrowserManager::ReloadUi() {
  UiView::ReloadAll();
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    for (const CefRefPtr<Tab>& tab : window->tabs()) {
      CefRefPtr<CefBrowser> page = tab->browser();
      if (page && tab->url.rfind(std::string(ui_scheme::kScheme) + "://", 0) == 0) page->ReloadIgnoreCache();
    }
  }
}

BrowserManager* BrowserManager::Get() {
  return g_manager;
}

// --- Windows and tabs -------------------------------------------------------

namespace {

constexpr int kSessionSaveDelayMs = 1000;
// Tabs' pictures: taken this long after a page loads or shows (once it has
// drawn), and of the tabs showing this often.
constexpr int kPreviewDelayMs = 800;
constexpr int kPreviewIntervalMs = 15000;
// Their width (a 220px tab's, at 2x).
constexpr int kPreviewWidth = 440;

std::string ProfileFolder() {
  return CefRequestContext::GetGlobalContext()->GetCachePath();
}

// `bounds`, moved onto the screen nearest it if it's no longer on one (the
// screens may have changed since).
CefRect OnScreen(CefRect bounds) {
  CefRefPtr<CefDisplay> display = CefDisplay::GetDisplayMatchingBounds(bounds, /*input_pixel_coords=*/false);
  if (!display) return bounds;
  const CefRect area = display->GetWorkArea();
  const bool visible = bounds.x < area.x + area.width && bounds.x + bounds.width > area.x &&
                       bounds.y < area.y + area.height && bounds.y + bounds.height > area.y;
  if (visible) return bounds;
  bounds.width = std::min(bounds.width, area.width);
  bounds.height = std::min(bounds.height, area.height);
  bounds.x = area.x + (area.width - bounds.width) / 2;
  bounds.y = area.y + (area.height - bounds.height) / 2;
  return bounds;
}

}  // namespace

void BrowserManager::Start(const std::string& url) {
  CEF_REQUIRE_UI_THREAD();
  std::vector<WindowLayout> saved = session::Read(ProfileFolder());
  for (WindowLayout& layout : saved) {
    layout.bounds = OnScreen(layout.bounds);
    CefRefPtr<BrowserWindow> window = new BrowserWindow(this, std::move(layout));
    windows_.push_back(window);
    CefWindow::CreateTopLevelWindow(window);
  }
  if (saved.empty() || !url.empty()) OpenWindow(url);
  CapturePreviewsLater();
}

// These tasks hold nothing (the manager lives as long as the app; a tab by
// its id): one still waiting as the app quits is dropped after CEF has shut
// down, and mustn't be what lets a page go then.
void BrowserManager::CapturePreviewsLater() {
  CefPostDelayedTask(TID_UI,
                     base::BindOnce(
                         [](BrowserManager* self) {
                           if (self->closing_) return;
                           for (const CefRefPtr<BrowserWindow>& window : self->windows_) window->CapturePreviews();
                           self->CapturePreviewsLater();
                         },
                         base::Unretained(this)),
                     kPreviewIntervalMs);
}

void BrowserManager::CapturePreviewSoon(CefRefPtr<Tab> tab) {
  CefPostDelayedTask(TID_UI,
                     base::BindOnce(
                         [](BrowserManager* self, int id) {
                           if (self->closing_) return;
                           for (const CefRefPtr<BrowserWindow>& window : self->windows_) {
                             for (const CefRefPtr<Tab>& tab : window->tabs()) {
                               if (tab->id() != id) continue;
                               CefRefPtr<CefWindow> cef = window->window();
                               if (cef && cef->IsVisible() && !cef->IsMinimized()) {
                                 self->CapturePreview(tab, window->is_private());
                               }
                               return;
                             }
                           }
                         },
                         base::Unretained(this), tab->id()),
                     kPreviewDelayMs);
}

void BrowserManager::CapturePreview(CefRefPtr<Tab> tab, bool is_private) {
  CefRefPtr<CefBrowser> browser = tab->browser();
  BrowserWindow* window = WindowOf(browser);
  Pane* pane = window ? window->Locate(browser) : nullptr;
  // Only a page that shows is drawn (a hidden one's picture never comes);
  // not one still blank, waiting for extensions (CreatePageView).
  if (!pane || pane->active_tab() != tab || IsWaiting(browser)) return;
  const CefRect bounds = tab->view()->GetBounds();
  if (bounds.width <= 0 || bounds.height <= 0) return;
  const double factor = std::min(1.0, static_cast<double>(kPreviewWidth) / bounds.width);
  // At full size, shrunk here (see tab_previews::Shrink for why).
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("format", "jpeg");
  params->SetInt("quality", 90);
  CefRefPtr<BrowserManager> self(this);
  devtools_->Call(browser, "Page.captureScreenshot", params,
                  [self, tab, is_private, factor](CefRefPtr<CefDictionaryValue> result) {
    if (!result) return;
    CefRefPtr<CefBinaryValue> data = CefBase64Decode(result->GetString("data"));
    if (!data || data->GetSize() == 0) return;
    std::string full(data->GetSize(), '\0');
    data->GetData(full.data(), full.size(), 0);
    std::string jpeg = tab_previews::Shrink(full, factor, 70);
    if (jpeg.empty()) return;
    if (tab->preview.empty()) tab->preview = tab_previews::NewToken();
    tab_previews::Put(tab->preview, std::move(jpeg), /*keep=*/!is_private);
    ++tab->preview_version;
    CefRefPtr<Tab> found;
    if (BrowserWindow* window = self->WindowOf(tab->browser(), &found)) {
      if (Pane* pane = window->Locate(tab->browser())) pane->UpdateTabBar();
    }
  });
}

std::vector<WindowLayout> BrowserManager::SessionWindows() const {
  // Back to front, as they're stacked on screen (so the front one, made
  // last, is in front again).
  std::vector<WindowLayout> layouts;
  NSArray<NSWindow*>* ordered = NSApp.orderedWindows;
  std::vector<std::pair<NSUInteger, const BrowserWindow*>> stacked;
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    if (window->is_private() || !window->window()) continue;
    NSWindow* ns = ((__bridge NSView*)window->window()->GetWindowHandle()).window;
    const NSUInteger at = [ordered indexOfObject:ns];
    stacked.emplace_back(at == NSNotFound ? NSUIntegerMax : at, window.get());
  }
  std::stable_sort(stacked.begin(), stacked.end(), [](const auto& a, const auto& b) { return a.first > b.first; });
  for (const auto& [at, window] : stacked) {
    WindowLayout layout = window->Snapshot();
    if (!layout.panes.empty()) layouts.push_back(std::move(layout));
  }
  return layouts;
}

void BrowserManager::SessionChanged() {
  // Not as the app quits: what was open then is already kept (CloseAll).
  if (closing_ || session_save_pending_) return;
  session_save_pending_ = true;
  CefPostDelayedTask(TID_UI,
                     base::BindOnce(
                         [](BrowserManager* self) {
                           if (!self->session_save_pending_) return;
                           self->session_save_pending_ = false;
                           if (!self->closing_) self->SaveSession(/*now=*/false);
                         },
                         base::Unretained(this)),
                     kSessionSaveDelayMs);
}

void BrowserManager::SaveSession(bool now) {
  session_save_pending_ = false;
  const std::vector<WindowLayout> windows = SessionWindows();
  session::Write(ProfileFolder(), windows, now);
  // The pictures kept are the session's tabs'.
  std::set<std::string> previews;
  for (const WindowLayout& layout : windows) {
    for (const WindowLayout::PaneTabs& pane : layout.panes) {
      for (const WindowLayout::SavedTab& tab : pane.tabs) {
        if (!tab.preview.empty()) previews.insert(tab.preview);
      }
    }
  }
  tab_previews::KeepOnly(std::move(previews));
}

void BrowserManager::OpenWindow(const std::string& url, bool is_private) {
  CEF_REQUIRE_UI_THREAD();
  // Cascade new windows a little so they don't sit exactly on top.
  const int offset = static_cast<int>(windows_.size() % 8) * 40;
  CefRefPtr<BrowserWindow> window =
      new BrowserWindow(this, CefRect(120 + offset, 80 + offset, 1280, 800), is_private, url);
  windows_.push_back(window);
  CefWindow::CreateTopLevelWindow(window);
}

void BrowserManager::OpenWindowWithTab(CefRefPtr<Tab> tab, const CefRect& bounds, bool is_private) {
  CEF_REQUIRE_UI_THREAD();
  CefRefPtr<BrowserWindow> window = new BrowserWindow(this, bounds, is_private, tab);
  windows_.push_back(window);
  CefWindow::CreateTopLevelWindow(window);
}

BrowserWindow* BrowserManager::WindowAt(const CefPoint& screen) const {
  // Front to back, as they're stacked on screen.
  for (NSWindow* ns in NSApp.orderedWindows) {
    if (!ns.visible || ns.miniaturized) continue;
    for (const CefRefPtr<BrowserWindow>& window : windows_) {
      CefRefPtr<CefWindow> cef = window->window();
      if (!cef || ((__bridge NSView*)cef->GetWindowHandle()).window != ns) continue;
      const CefRect r = cef->GetBoundsInScreen();
      if (screen.x >= r.x && screen.y >= r.y && screen.x < r.x + r.width && screen.y < r.y + r.height) {
        return window.get();
      }
    }
  }
  return nullptr;
}

CefRefPtr<CefBrowserView> BrowserManager::CreatePageView(const std::string& url, bool is_private) {
  CefBrowserSettings settings;
  // With extensions, the page starts blank and loads `url` once their
  // scripts are in place (OnAfterCreated), so they run in its first page
  // from the start.
  const bool wait = !is_private && !url.empty() && extensions_->HasExtensions();
  CefRefPtr<CefBrowserView> view = CefBrowserView::CreateBrowserView(
      this, wait ? std::string(kBlankUrl) : url, settings, NewPageExtraInfo(), is_private ? PrivateContext() : nullptr,
      view_delegate_);
  if (wait) waiting_to_load_.push_back({view, url});
  return view;
}

CefRefPtr<Tab> BrowserManager::CreateTab(const std::string& url, bool is_private) {
  CefRefPtr<CefBrowserView> view = CreatePageView(url, is_private);
  CefRefPtr<Tab> tab = new Tab(next_tab_id_++, view);
  tab->url = url;
  return tab;
}

CefRefPtr<Tab> BrowserManager::AdoptTab(CefRefPtr<CefBrowserView> view) {
  return new Tab(next_tab_id_++, view);
}

CefRefPtr<Tab> BrowserManager::SavedTab(const WindowLayout::SavedTab& saved) {
  CefRefPtr<Tab> tab = new Tab(next_tab_id_++, nullptr);
  tab->url = saved.url;
  tab->title = saved.title;
  tab->favicon = saved.favicon;
  // Its picture, as it was.
  if (tab_previews::Load(saved.preview)) tab->preview = saved.preview;
  // Visited before: loading it again isn't another visit.
  tab->visited = saved.url;
  return tab;
}

void BrowserManager::LoadTab(CefRefPtr<Tab> tab, bool is_private) {
  if (tab->loaded()) return;
  tab->Load(CreatePageView(tab->url, is_private));
}

void BrowserManager::OnPopupViewCreated(CefRefPtr<CefBrowserView> opener, CefRefPtr<CefBrowserView> popup) {
  BrowserWindow* window = WindowOf(opener->GetBrowser());
  window = window ? window : current_;
  if (window) window->AdoptPopup(opener->GetBrowser(), popup, popup_foreground_);
}

void BrowserManager::OnWindowCreated(BrowserWindow* window) {
  current_ = window;
}

void BrowserManager::OnWindowActivated(BrowserWindow* window) {
  current_ = window;
}

void BrowserManager::OnWindowDestroyed(BrowserWindow* window) {
  CefRefPtr<BrowserWindow> keep_alive(window);
  windows_.erase(std::remove_if(windows_.begin(), windows_.end(),
                                [&](const CefRefPtr<BrowserWindow>& w) { return w.get() == window; }),
                 windows_.end());
  if (current_ == window) current_ = windows_.empty() ? nullptr : windows_.back().get();
  // The last private window: its profile goes once its pages have (they
  // hold it too), and with it everything they kept.
  if (std::none_of(windows_.begin(), windows_.end(), [](const CefRefPtr<BrowserWindow>& w) { return w->is_private(); })) {
    private_context_ = nullptr;
  }
  if (windows_.empty() && !closing_) {
    // The last window closed (not the app quitting): nothing to bring back.
    SaveSession(/*now=*/true);
  } else {
    SessionChanged();
  }
  if (windows_.empty()) {
    popout_->Close();
    // Once our UI's pages in windows of their own (find rows) have closed.
    UiView::WhenOwnWindowPagesClosed([] { CefQuitMessageLoop(); });
  }
}

// --- Reopen Closed Tab --------------------------------------------------------

namespace {
// As many as Chrome keeps.
constexpr size_t kMaxClosed = 25;
}  // namespace

void BrowserManager::RememberClosedTab(const BrowserWindow* window,
                                       const std::string& url,
                                       int pane_index,
                                       int index,
                                       bool pane_closed) {
  // A tab that only ever showed the start page has nothing to bring back.
  if (url.empty() || url == ui_scheme::kStartUrl) return;
  Remember(ClosedTab{url, window->id(), pane_index, index, pane_closed});
}

void BrowserManager::RememberClosedWindow(WindowLayout layout) {
  Remember(std::move(layout));
}

void BrowserManager::Remember(std::variant<ClosedTab, WindowLayout> item) {
  // Not what closes as the app quits.
  if (closing_) return;
  closed_.push_back(std::move(item));
  if (closed_.size() > kMaxClosed) closed_.erase(closed_.begin());
}

bool BrowserManager::NextReopenIsWindow() const {
  return !closed_.empty() && std::holds_alternative<WindowLayout>(closed_.back());
}

void BrowserManager::ReopenClosed() {
  if (closed_.empty()) return;
  std::variant<ClosedTab, WindowLayout> item = std::move(closed_.back());
  closed_.pop_back();
  if (WindowLayout* layout = std::get_if<WindowLayout>(&item)) {
    CefRefPtr<BrowserWindow> window = new BrowserWindow(this, std::move(*layout));
    windows_.push_back(window);
    CefWindow::CreateTopLevelWindow(window);
    return;
  }
  const ClosedTab& tab = std::get<ClosedTab>(item);
  // Back in its window if that's still open, else in a new one.
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    if (window->id() == tab.window_id) {
      window->ReopenTab(tab.url, tab.pane_index, tab.index, tab.pane_closed);
      return;
    }
  }
  OpenWindow(tab.url);
}

BrowserWindow* BrowserManager::WindowOf(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab) const {
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    if (window->Locate(browser, tab)) return window.get();
  }
  return nullptr;
}

void BrowserManager::CloseAll() {
  CEF_REQUIRE_UI_THREAD();
  // What's open now is what the next start brings back (before the windows
  // close, which would take it with them).
  if (!closing_) SaveSession(/*now=*/true);
  closing_ = true;
  popout_->Close();
  for (const CefRefPtr<BrowserWindow>& w : std::vector<CefRefPtr<BrowserWindow>>(windows_)) {
    if (w->window()) w->window()->Close();
  }
  if (windows_.empty()) CefQuitMessageLoop();
}

void BrowserManager::OnMessageLoopEnded() {
  if (session_save_pending_ && !closing_) SaveSession(/*now=*/true);
  history_->SaveNow();
}

CefRefPtr<CefRequestContext> BrowserManager::PrivateContext() {
  if (!private_context_) {
    // No cache path: in memory only.
    CefRequestContextSettings settings;
    private_context_ = CefRequestContext::CreateContext(settings, nullptr);
    DisableChromiumHistory(private_context_);
    // Its own start page (scheme handlers are per profile).
    ui_scheme::RegisterHandlerFactory(private_context_, /*is_private=*/true);
  }
  return private_context_;
}

CefRefPtr<CefDictionaryValue> BrowserManager::NewPageExtraInfo() const {
  const std::string script = popout_->ScriptForNewPages();
  if (script.empty()) return nullptr;
  CefRefPtr<CefDictionaryValue> extra_info = CefDictionaryValue::Create();
  extra_info->SetString(kInitScriptKey, script);
  return extra_info;
}

// --- Commands ---------------------------------------------------------------

bool BrowserManager::CanRun(Command command) const {
  CefRefPtr<CefBrowser> page = current_ ? current_->active_browser() : nullptr;
  switch (command) {
    case Command::kNewTab:
    case Command::kNewWindow:
    case Command::kNewPrivateWindow:
    case Command::kAbout:
      return true;
    case Command::kReopenClosed:
      return !closed_.empty();
    case Command::kUpdate:
      return !updater::AvailableVersion().empty();
    case Command::kBack:
      return page && page->CanGoBack();
    case Command::kForward:
      return page && page->CanGoForward();
    case Command::kZoomIn:
      return page && page->GetHost()->CanZoom(CEF_ZOOM_COMMAND_IN);
    case Command::kZoomOut:
      return page && page->GetHost()->CanZoom(CEF_ZOOM_COMMAND_OUT);
    case Command::kZoomReset:
      return page && page->GetHost()->CanZoom(CEF_ZOOM_COMMAND_RESET);
    case Command::kTogglePopout:
      return popout_->IsOpen() || page;
    case Command::kFind:
      return page != nullptr;
    case Command::kFindNext:
    case Command::kFindPrevious:
      return current_ && current_->active_pane() && current_->active_pane()->CanFindAgain();
    default:
      return current_ != nullptr;
  }
}

void BrowserManager::Run(Command command) {
  CEF_REQUIRE_UI_THREAD();
  if (command == Command::kNewWindow || (command == Command::kNewTab && !current_)) {
    OpenWindow(std::string());
    return;
  }
  if (command == Command::kNewPrivateWindow) {
    OpenWindow(std::string(), /*is_private=*/true);
    return;
  }
  if (command == Command::kReopenClosed) {
    ReopenClosed();
    return;
  }
  if (command == Command::kUpdate) {
    updater::ShowUpdate();
    return;
  }
  if (command == Command::kAbout) {
    ShowAbout();
    return;
  }
  if (!current_) return;
  CefRefPtr<Tab> tab = current_->active_tab();
  CefRefPtr<CefBrowser> page = tab ? tab->browser() : nullptr;
  switch (command) {
    case Command::kNewTab:
      current_->NewTab();
      break;
    case Command::kCloseTab:
      if (tab) current_->CloseTab(tab);
      break;
    case Command::kCloseWindow:
      if (current_->window()) current_->window()->Close();
      break;
    case Command::kNextTab:
      current_->active_pane()->ActivateRelative(1);
      break;
    case Command::kPreviousTab:
      current_->active_pane()->ActivateRelative(-1);
      break;
    case Command::kTogglePopout:
      popout_->Toggle(page);
      break;
    case Command::kFind:
      current_->active_pane()->OpenFind();
      break;
    case Command::kFindNext:
    case Command::kFindPrevious:
      current_->active_pane()->FindAgain(command == Command::kFindNext);
      break;
    default:
      if (!page) break;
      switch (command) {
        case Command::kBack:
          page->GoBack();
          break;
        case Command::kForward:
          page->GoForward();
          break;
        case Command::kReload:
          page->Reload();
          break;
        case Command::kReloadIgnoringCache:
          page->ReloadIgnoreCache();
          break;
        case Command::kZoomIn:
          page->GetHost()->Zoom(CEF_ZOOM_COMMAND_IN);
          break;
        case Command::kZoomOut:
          page->GetHost()->Zoom(CEF_ZOOM_COMMAND_OUT);
          break;
        case Command::kZoomReset:
          page->GetHost()->Zoom(CEF_ZOOM_COMMAND_RESET);
          break;
        case Command::kDevTools: {
          CefWindowInfo window_info;
          CefBrowserSettings settings;
          page->GetHost()->ShowDevTools(window_info, nullptr, settings, CefPoint());
          break;
        }
        case Command::kViewSource:
          page->GetMainFrame()->ViewSource();
          break;
        case Command::kPrint:
          page->GetHost()->Print();
          break;
        default:
          break;
      }
  }
}

// Shift+Cmd+P: pop out (or put back). Handled before the page sees the key,
// so it works while a page has focus (the menu item shows the shortcut).
bool BrowserManager::OnPreKeyEvent(CefRefPtr<CefBrowser> browser,
                                   const CefKeyEvent& event,
                                   CefEventHandle os_event,
                                   bool* is_keyboard_shortcut) {
  constexpr uint32_t kModifiers = EVENTFLAG_COMMAND_DOWN | EVENTFLAG_SHIFT_DOWN | EVENTFLAG_CONTROL_DOWN |
                                  EVENTFLAG_ALT_DOWN;
  if (event.type != KEYEVENT_RAWKEYDOWN || event.windows_key_code != 'P' ||
      (event.modifiers & kModifiers) != (EVENTFLAG_COMMAND_DOWN | EVENTFLAG_SHIFT_DOWN)) {
    return false;
  }
  popout_->Toggle(browser);
  return true;
}

// --- Life span --------------------------------------------------------------

bool BrowserManager::OnBeforePopup(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   int popup_id,
                                   const CefString& target_url,
                                   const CefString& target_frame_name,
                                   WindowOpenDisposition target_disposition,
                                   bool user_gesture,
                                   const CefPopupFeatures& popup_features,
                                   CefWindowInfo& window_info,
                                   CefRefPtr<CefClient>& client,
                                   CefBrowserSettings& settings,
                                   CefRefPtr<CefDictionaryValue>& extra_info,
                                   bool* no_javascript_access) {
  CEF_REQUIRE_UI_THREAD();
  if (popout_->OnBeforePopup(browser, target_disposition, window_info, client)) return false;
  // Any other popup or new tab: CEF creates its view and PageViewDelegate
  // hands it to us as a tab beside its opener (keeping window.opener).
  popup_foreground_ = target_disposition != CEF_WOD_NEW_BACKGROUND_TAB;
  extra_info = NewPageExtraInfo();
  return false;
}

void BrowserManager::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  devtools_->Attach(browser);
  // Extensions don't run in private windows (as Chrome's don't, unless
  // allowed).
  const bool is_private = private_context_ && browser->GetHost()->GetRequestContext()->IsSame(private_context_);
  // A page that waits for them (CreatePageView) loads its address once
  // they're in place, or after a moment if they never answer.
  CefRefPtr<CefBrowserView> view = CefBrowserView::GetForBrowser(browser);
  for (auto it = waiting_to_load_.begin(); view && it != waiting_to_load_.end(); ++it) {
    if (!it->first->IsSame(view)) continue;
    waiting_pages_[browser->GetIdentifier()] = {browser, it->second};
    waiting_to_load_.erase(it);
    // Holds only the page's id (as CapturePreviewsLater's tasks do).
    CefPostDelayedTask(TID_UI,
                       base::BindOnce(&BrowserManager::LoadWaitingPage, base::Unretained(this), browser->GetIdentifier()),
                       kExtensionsWaitMs);
    break;
  }
  if (is_private) return;
  const int id = browser->GetIdentifier();
  extensions_->OnPageCreated(browser, [this, id] { LoadWaitingPage(id); });
}

void BrowserManager::LoadWaitingPage(int id) {
  auto it = waiting_pages_.find(id);
  if (it == waiting_pages_.end()) return;
  const auto [browser, url] = it->second;
  waiting_pages_.erase(it);
  blank_in_history_.insert(id);
  browser->GetMainFrame()->LoadURL(url);
}

bool BrowserManager::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  // A tab's page has run its unload handlers and is closing. CEF would ask
  // the page's window to close, but a tab isn't a window (and a background
  // tab's page isn't in one): take the tab out instead. Releasing its view
  // completes the close (OnBeforeClose).
  if (BrowserWindow* window = WindowOf(browser)) {
    window->OnTabClosed(browser);
    return true;
  }
  return false;
}

void BrowserManager::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  devtools_->Detach(browser);
  extension_router_->OnBeforeClose(browser);
  extensions_->OnPageClosed(browser);
  waiting_pages_.erase(browser->GetIdentifier());
  blank_in_history_.erase(browser->GetIdentifier());
  if (BrowserWindow* window = WindowOf(browser)) window->OnTabClosed(browser);
}

// The pane whose page has the keyboard is the one commands act on.
void BrowserManager::OnGotFocus(CefRefPtr<CefBrowser> browser) {
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    if (Pane* pane = window->Locate(browser)) window->SetActivePane(pane);
  }
}

// --- Page state -------------------------------------------------------------

void BrowserManager::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     const CefString& url) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || !frame->IsMain() || IsWaiting(browser)) return;
  // The blank page it waited on (CreatePageView) leaves its history.
  if (blank_in_history_.erase(browser->GetIdentifier())) devtools_->Call(browser, "Page.resetNavigationHistory", nullptr);
  tab->url = url;
  if (tab->visited != tab->url) {
    tab->visited = tab->url;
    if (History* history = window->history()) history->AddVisit(tab->url);
  }
  window->OnTabChanged(browser);
}

void BrowserManager::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || IsWaiting(browser)) return;
  tab->title = title;
  if (History* history = window->history()) history->SetTitle(tab->url, tab->title);
  window->OnTabChanged(browser);
}

// Where a page's favicon is if it declares none: /favicon.ico on its origin,
// for web pages (as Chrome's favicon fetching assumes; CEF reports only the
// icons a page declares).
static std::string DefaultFavicon(const std::string& url) {
  CefURLParts parts;
  if (!CefParseURL(url, parts)) return std::string();
  const std::string scheme = CefString(&parts.scheme);
  if (scheme != "http" && scheme != "https") return std::string();
  return CefString(&parts.origin).ToString() + "favicon.ico";
}

void BrowserManager::OnLoadStart(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 TransitionType transition_type) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || !frame->IsMain() || IsWaiting(browser)) return;
  // A new document: until it declares icons (OnFaviconURLChange), its
  // origin's default.
  tab->favicon = DefaultFavicon(frame->GetURL());
  window->OnTabChanged(browser);
}

void BrowserManager::OnFaviconURLChange(CefRefPtr<CefBrowser> browser, const std::vector<CefString>& icon_urls) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || IsWaiting(browser)) return;
  tab->favicon = icon_urls.empty() ? DefaultFavicon(browser->GetMainFrame()->GetURL()) : icon_urls.front().ToString();
  window->OnTabChanged(browser);
}

void BrowserManager::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                          bool is_loading,
                                          bool can_go_back,
                                          bool can_go_forward) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || IsWaiting(browser)) return;
  tab->loading = is_loading;
  if (!is_loading) {
    if (Pane* pane = window->Locate(browser)) pane->OnPageLoaded(tab);
    CapturePreviewSoon(tab);
  }
  window->OnTabChanged(browser);
}

void BrowserManager::OnFindResult(CefRefPtr<CefBrowser> browser,
                                  int identifier,
                                  int count,
                                  const CefRect& selection_rect,
                                  int active_match_ordinal,
                                  bool final_update) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  Pane* pane = window ? window->Locate(browser) : nullptr;
  if (pane) pane->OnFindResult(tab, count, active_match_ordinal);
}

// Links opened "in a new tab" or "window" from a page: Cmd-click (a
// background tab), Cmd-Shift-click (a foreground tab), Shift-click (a new
// window), and middle-click. As Chrome does, beside the opener's tab.
bool BrowserManager::OnOpenURLFromTab(CefRefPtr<CefBrowser> browser,
                                      CefRefPtr<CefFrame> frame,
                                      const CefString& target_url,
                                      WindowOpenDisposition target_disposition,
                                      bool user_gesture) {
  CEF_REQUIRE_UI_THREAD();
  return OpenLink(browser, target_url, target_disposition);
}

bool BrowserManager::OpenLink(CefRefPtr<CefBrowser> browser,
                              const std::string& url,
                              WindowOpenDisposition disposition) {
  switch (disposition) {
    case CEF_WOD_NEW_FOREGROUND_TAB:
    case CEF_WOD_NEW_BACKGROUND_TAB: {
      BrowserWindow* window = WindowOf(browser);
      Pane* pane = window ? window->Locate(browser) : nullptr;
      if (!pane) return false;
      CefRefPtr<Tab> tab = window->OpenTab(url, pane, disposition == CEF_WOD_NEW_FOREGROUND_TAB);
      if (disposition == CEF_WOD_NEW_FOREGROUND_TAB) tab->view()->RequestFocus();
      return true;
    }
    case CEF_WOD_NEW_WINDOW: {
      // A private window's links open private windows.
      BrowserWindow* window = WindowOf(browser);
      OpenWindow(url, window && window->is_private());
      return true;
    }
    default:
      return false;  // In this tab.
  }
}

// --- Context menu -------------------------------------------------------------

namespace {

// Our items in a page's context menu (CEF leaves this range to clients).
enum LinkCommand {
  kOpenLinkInNewTab = MENU_ID_USER_FIRST,
  kOpenLinkInNewWindow,
  kOpenLinkInPrivateWindow,
};

}  // namespace

// A link's menu starts with ways to open it elsewhere, as Chrome's and
// Safari's do. In a private window a new window is private anyway, so
// there's no separate private item.
void BrowserManager::OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                                         CefRefPtr<CefFrame> frame,
                                         CefRefPtr<CefContextMenuParams> params,
                                         CefRefPtr<CefMenuModel> model) {
  CEF_REQUIRE_UI_THREAD();
  BrowserWindow* window = WindowOf(browser);
  if (!window || !(params->GetTypeFlags() & CM_TYPEFLAG_LINK)) return;
  size_t index = 0;
  model->InsertItemAt(index++, kOpenLinkInNewTab, "Open Link in New Tab");
  model->InsertItemAt(index++, kOpenLinkInNewWindow, "Open Link in New Window");
  if (!window->is_private()) {
    model->InsertItemAt(index++, kOpenLinkInPrivateWindow, "Open Link in Private Window");
  }
  if (model->GetCount() > index) model->InsertSeparatorAt(index);
}

bool BrowserManager::OnContextMenuCommand(CefRefPtr<CefBrowser> browser,
                                          CefRefPtr<CefFrame> frame,
                                          CefRefPtr<CefContextMenuParams> params,
                                          int command_id,
                                          EventFlags event_flags) {
  CEF_REQUIRE_UI_THREAD();
  const std::string url = params->GetLinkUrl();
  switch (command_id) {
    case kOpenLinkInNewTab:
      // Behind the current tab, as Chrome opens it.
      return OpenLink(browser, url, CEF_WOD_NEW_BACKGROUND_TAB);
    case kOpenLinkInNewWindow:
      return OpenLink(browser, url, CEF_WOD_NEW_WINDOW);
    case kOpenLinkInPrivateWindow:
      OpenWindow(url, /*is_private=*/true);
      return true;
    default:
      return false;
  }
}

bool BrowserManager::OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request,
                                    bool user_gesture,
                                    bool is_redirect) {
  extension_router_->OnBeforeBrowse(browser, frame);
  // Web pages never load the browser's own UI.
  return ui_scheme::IsUiUrl(request->GetURL());
}

void BrowserManager::OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                               TerminationStatus status,
                                               int error_code,
                                               const CefString& error_string) {
  extension_router_->OnRenderProcessTerminated(browser);
}

bool BrowserManager::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                              CefRefPtr<CefFrame> frame,
                                              CefProcessId source_process,
                                              CefRefPtr<CefProcessMessage> message) {
  return extension_router_->OnProcessMessageReceived(browser, frame, source_process, message);
}
