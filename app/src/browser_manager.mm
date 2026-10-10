// Copyright (c) 2026 Richard Kielty. MIT License.

#include "browser_manager.h"

#include <algorithm>

#include "include/cef_app.h"
#include "include/cef_id_mappers.h"
#include "include/wrapper/cef_helpers.h"

namespace {

BrowserManager* g_manager = nullptr;

constexpr char kNewPageUrl[] = "chrome://newtab/";

// Key read by the renderer (renderer_app.cc).
constexpr char kInitScriptKey[] = "openp41ge.init_script";

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

// --- Page windows -----------------------------------------------------------

void BrowserManager::OpenPageWindow(const std::string& url) {
  CEF_REQUIRE_UI_THREAD();
  CefBrowserSettings settings;
  OpenPageWindow(CefBrowserView::CreateBrowserView(this, url.empty() ? kNewPageUrl : url, settings,
                                                   NewPageExtraInfo(), nullptr, view_delegate_));
}

void BrowserManager::OpenPageWindow(CefRefPtr<CefBrowserView> view) {
  CEF_REQUIRE_UI_THREAD();
  // Cascade new windows a little so they don't sit exactly on top.
  const int offset = static_cast<int>(windows_.size() % 8) * 40;
  CefRefPtr<PageWindow> page_window = new PageWindow(this, view, CefRect(120 + offset, 80 + offset, 1280, 800));
  windows_.push_back(page_window);
  CefWindow::CreateTopLevelWindow(page_window);
}

void BrowserManager::OnPageWindowCreated(PageWindow* page_window) {
  current_ = page_window;
}

void BrowserManager::OnPageWindowActivated(PageWindow* page_window) {
  current_ = page_window;
}

void BrowserManager::OnPageWindowDestroyed(PageWindow* page_window) {
  CefRefPtr<PageWindow> keep_alive(page_window);
  windows_.erase(std::remove_if(windows_.begin(), windows_.end(),
                                [&](const CefRefPtr<PageWindow>& w) { return w.get() == page_window; }),
                 windows_.end());
  if (current_ == page_window) current_ = windows_.empty() ? nullptr : windows_.back().get();
  if (windows_.empty()) {
    popout_->Close();
    CefQuitMessageLoop();
  }
}

PageWindow* BrowserManager::PageWindowFor(CefRefPtr<CefBrowser> browser) const {
  for (const CefRefPtr<PageWindow>& w : windows_) {
    if (browser && w->browser() && w->browser()->IsSame(browser)) return w.get();
  }
  return nullptr;
}

CefRefPtr<CefBrowser> BrowserManager::CurrentPage() const {
  return current_ ? current_->browser() : nullptr;
}

void BrowserManager::ExecuteChromeCommand(int command_id) {
  if (CefRefPtr<CefBrowser> page = CurrentPage()) {
    page->GetHost()->ExecuteChromeCommand(command_id, CEF_WOD_CURRENT_TAB);
  }
}

void BrowserManager::CloseCurrentWindow() {
  if (current_ && current_->window()) current_->window()->Close();
}

void BrowserManager::CloseAll() {
  CEF_REQUIRE_UI_THREAD();
  closing_ = true;
  popout_->Close();
  for (const CefRefPtr<PageWindow>& w : std::vector<CefRefPtr<PageWindow>>(windows_)) {
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

// --- Pop-out ----------------------------------------------------------------

void BrowserManager::TogglePopout() {
  popout_->Toggle(CurrentPage());
}

void BrowserManager::OnPopoutClosed(CefRefPtr<CefBrowser> source) {
  // The element is back in its page. If that page was only kept open for the
  // pop-out (another page window is now in front), close it too.
  PageWindow* source_window = PageWindowFor(source);
  if (source_window && source_window != current_ && !closing_ && windows_.size() > 1) {
    source_window->window()->Close();
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
  if (popout_->OnBeforePopup(browser, target_disposition, client)) return false;
  // Any other popup or new tab: CEF creates its browser view and
  // PageViewDelegate puts it in a new page window, keeping its opener.
  extra_info = NewPageExtraInfo();
  return false;
}

void BrowserManager::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  devtools_->Attach(browser);
}

void BrowserManager::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  devtools_->Detach(browser);
}

// --- Display / commands ----------------------------------------------

void BrowserManager::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  if (PageWindow* w = PageWindowFor(browser)) w->window()->SetTitle(title);
}

bool BrowserManager::OnChromeCommand(CefRefPtr<CefBrowser> browser,
                                     int command_id,
                                     cef_window_open_disposition_t disposition) {
  // Pages have no tab strip yet: new tabs are new page windows, and closing
  // the tab closes its window.
  static const int kNewTab = cef_id_for_command_id_name("IDC_NEW_TAB");
  static const int kNewWindow = cef_id_for_command_id_name("IDC_NEW_WINDOW");
  static const int kCloseTab = cef_id_for_command_id_name("IDC_CLOSE_TAB");
  static const int kCloseWindow = cef_id_for_command_id_name("IDC_CLOSE_WINDOW");
  if (command_id == kNewTab || command_id == kNewWindow) {
    OpenPageWindow(kNewPageUrl);
    return true;
  }
  if (command_id == kCloseTab || command_id == kCloseWindow) {
    if (PageWindow* w = PageWindowFor(browser)) w->window()->Close();
    return true;
  }
  return false;
}
