// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_manager.h"

#include <algorithm>

#include "include/cef_app.h"
#include "include/wrapper/cef_helpers.h"

#include "ui/ui_scheme.h"

namespace {

BrowserManager* g_manager = nullptr;

// Key read by the renderer (renderer_app.cc).
constexpr char kInitScriptKey[] = "openp41ge.init_script";

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
      view_delegate_(new PageViewDelegate(this)) {
  DCHECK(!g_manager);
  g_manager = this;
}

BrowserManager* BrowserManager::Get() {
  return g_manager;
}

// --- Windows and tabs -------------------------------------------------------

void BrowserManager::OpenWindow(const std::string& url) {
  CEF_REQUIRE_UI_THREAD();
  // Cascade new windows a little so they don't sit exactly on top.
  const int offset = static_cast<int>(windows_.size() % 8) * 40;
  CefRefPtr<BrowserWindow> window = new BrowserWindow(this, CefRect(120 + offset, 80 + offset, 1280, 800), url);
  windows_.push_back(window);
  CefWindow::CreateTopLevelWindow(window);
}

CefRefPtr<Tab> BrowserManager::CreateTab(const std::string& url) {
  CefBrowserSettings settings;
  CefRefPtr<CefBrowserView> view =
      CefBrowserView::CreateBrowserView(this, url, settings, NewPageExtraInfo(), nullptr, view_delegate_);
  CefRefPtr<Tab> tab = new Tab(next_tab_id_++, view);
  tab->url = url;
  return tab;
}

CefRefPtr<Tab> BrowserManager::AdoptTab(CefRefPtr<CefBrowserView> view) {
  return new Tab(next_tab_id_++, view);
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
  if (windows_.empty()) {
    popout_->Close();
    CefQuitMessageLoop();
  }
}

BrowserWindow* BrowserManager::WindowOf(CefRefPtr<CefBrowser> browser, CefRefPtr<Tab>* tab) const {
  for (const CefRefPtr<BrowserWindow>& window : windows_) {
    if (window->Locate(browser, tab)) return window.get();
  }
  return nullptr;
}

void BrowserManager::CloseAll() {
  CEF_REQUIRE_UI_THREAD();
  closing_ = true;
  popout_->Close();
  for (const CefRefPtr<BrowserWindow>& w : std::vector<CefRefPtr<BrowserWindow>>(windows_)) {
    if (w->window()) w->window()->Close();
  }
  if (windows_.empty()) CefQuitMessageLoop();
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
      return true;
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
  if (!current_) return;
  CefRefPtr<Tab> tab = current_->active_tab();
  CefRefPtr<CefBrowser> page = tab ? tab->browser() : nullptr;
  switch (command) {
    case Command::kNewTab:
      current_->ShowPalette(/*new_tab=*/true);
      break;
    case Command::kOpenLocation:
      current_->ShowPalette(/*new_tab=*/false);
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
  if (BrowserWindow* window = WindowOf(browser)) window->OnTabClosed(browser);
}

// --- Page state -------------------------------------------------------------

void BrowserManager::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                     CefRefPtr<CefFrame> frame,
                                     const CefString& url) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window || !frame->IsMain()) return;
  tab->url = url;
  window->OnTabChanged(browser);
}

void BrowserManager::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window) return;
  tab->title = title;
  window->OnTabChanged(browser);
}

void BrowserManager::OnFaviconURLChange(CefRefPtr<CefBrowser> browser, const std::vector<CefString>& icon_urls) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window) return;
  tab->favicon = icon_urls.empty() ? std::string() : icon_urls.front().ToString();
  window->OnTabChanged(browser);
}

void BrowserManager::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                          bool is_loading,
                                          bool can_go_back,
                                          bool can_go_forward) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window) return;
  tab->loading = is_loading;
  window->OnTabChanged(browser);
}

bool BrowserManager::OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefRequest> request,
                                    bool user_gesture,
                                    bool is_redirect) {
  // Web pages never load the browser's own UI.
  return ui_scheme::IsUiUrl(request->GetURL());
}
