// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_manager.h"

#import <Cocoa/Cocoa.h>

#include <algorithm>

#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/cef_request_context.h"
#include "include/wrapper/cef_helpers.h"

#include "ui/ui_scheme.h"

namespace {

BrowserManager* g_manager = nullptr;

// Key read by the renderer (renderer_app.cc).
constexpr char kInitScriptKey[] = "openp41ge.init_script";

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
      view_delegate_(new PageViewDelegate(this)),
      history_(std::make_unique<History>(CefRequestContext::GetGlobalContext()->GetCachePath())) {
  DCHECK(!g_manager);
  g_manager = this;
  DisableChromiumHistory(CefRequestContext::GetGlobalContext());
}

BrowserManager* BrowserManager::Get() {
  return g_manager;
}

// --- Windows and tabs -------------------------------------------------------

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

CefRefPtr<Tab> BrowserManager::CreateTab(const std::string& url, bool is_private) {
  CefBrowserSettings settings;
  CefRefPtr<CefBrowserView> view = CefBrowserView::CreateBrowserView(
      this, url, settings, NewPageExtraInfo(), is_private ? PrivateContext() : nullptr, view_delegate_);
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
  // The last private window: its profile goes once its pages have (they
  // hold it too), and with it everything they kept.
  if (std::none_of(windows_.begin(), windows_.end(), [](const CefRefPtr<BrowserWindow>& w) { return w->is_private(); })) {
    private_context_ = nullptr;
  }
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

void BrowserManager::OnMessageLoopEnded() {
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
  if (command == Command::kNewPrivateWindow) {
    OpenWindow(std::string(), /*is_private=*/true);
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
  if (!window || !frame->IsMain()) return;
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
  if (!window) return;
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
  if (!window || !frame->IsMain()) return;
  // A new document: until it declares icons (OnFaviconURLChange), its
  // origin's default.
  tab->favicon = DefaultFavicon(frame->GetURL());
  window->OnTabChanged(browser);
}

void BrowserManager::OnFaviconURLChange(CefRefPtr<CefBrowser> browser, const std::vector<CefString>& icon_urls) {
  CefRefPtr<Tab> tab;
  BrowserWindow* window = WindowOf(browser, &tab);
  if (!window) return;
  tab->favicon = icon_urls.empty() ? DefaultFavicon(browser->GetMainFrame()->GetURL()) : icon_urls.front().ToString();
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
  // Web pages never load the browser's own UI.
  return ui_scheme::IsUiUrl(request->GetURL());
}
