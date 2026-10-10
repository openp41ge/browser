// Copyright (c) 2026 Richard Kielty. MIT License.

#include "spike_client.h"

#include <dispatch/dispatch.h>

#include <algorithm>

#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/views/cef_box_layout.h"
#include "include/views/cef_label_button.h"
#include "include/wrapper/cef_helpers.h"

#include "popout_script.h"

namespace {

// Pages: Chrome style with Chrome's toolbar off, and Document PiP pop-outs
// that are frameless and placeable by script.
class PageViewDelegate : public CefBrowserViewDelegate {
 public:
  cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
  ChromeToolbarType GetChromeToolbarType(CefRefPtr<CefBrowserView> view) override {
    return CEF_CTT_NONE;
  }
  bool UseFramelessWindowForPictureInPicture(CefRefPtr<CefBrowserView> view) override {
    return true;
  }
  bool AllowMoveForPictureInPicture(CefRefPtr<CefBrowserView> view) override { return true; }

 private:
  IMPLEMENT_REFCOUNTING(PageViewDelegate);
};

class PageWindowDelegate : public CefWindowDelegate {
 public:
  PageWindowDelegate(CefRefPtr<SpikeClient> client, std::string url, CefRect bounds)
      : client_(client), url_(std::move(url)), bounds_(bounds) {}

  void OnWindowCreated(CefRefPtr<CefWindow> window) override {
    client_->OnPageWindowCreated(window, url_);
  }
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override {
    if (active) client_->OnPageWindowActivated(window);
  }
  bool CanClose(CefRefPtr<CefWindow> window) override { return client_->CanClosePageWindow(window); }
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override {
    client_->OnPageWindowDestroyed(window);
    client_ = nullptr;
  }
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }

 private:
  CefRefPtr<SpikeClient> client_;
  std::string url_;
  CefRect bounds_;
  IMPLEMENT_REFCOUNTING(PageWindowDelegate);
};

// A page window's offer bar buttons.
class BannerButtons : public CefButtonDelegate {
 public:
  enum { kLabel = 1, kPlay = 2, kDismiss = 3 };
  explicit BannerButtons(CefRefPtr<SpikeClient> client) : client_(client) {}

  void OnButtonPressed(CefRefPtr<CefButton> button) override {
    CefRefPtr<CefWindow> window = button->GetWindow();
    if (button->GetID() == kPlay) client_->PlayInPopout(window);
    if (button->GetID() == kDismiss) client_->DismissBanner(window);
  }

 private:
  CefRefPtr<SpikeClient> client_;
  IMPLEMENT_REFCOUNTING(BannerButtons);
};

}  // namespace

SpikeClient::SpikeClient(std::string url, std::string selector)
    : start_url_(std::move(url)),
      selector_(std::move(selector)),
      page_view_delegate_(new PageViewDelegate()) {}

// --- Page windows -----------------------------------------------------------

void SpikeClient::Start() {
  OpenPageWindow(start_url_);
}

void SpikeClient::OpenPageWindow(const std::string& url) {
  // Cascade new windows a little so they don't sit exactly on top.
  const int offset = static_cast<int>(pages_.size()) * 40;
  CefWindow::CreateTopLevelWindow(
      new PageWindowDelegate(this, url, CefRect(120 + offset, 80 + offset, 1280, 800)));
}

void SpikeClient::OnPageWindowCreated(CefRefPtr<CefWindow> window, const std::string& url) {
  CefBoxLayoutSettings column;
  column.horizontal = false;
  CefRefPtr<CefBoxLayout> layout = window->SetToBoxLayout(column);

  // "Something is playing in the pop-out. [Play in pop-out] [Dismiss]"
  CefRefPtr<BannerButtons> buttons = new BannerButtons(this);
  CefRefPtr<CefPanel> banner = CefPanel::CreatePanel(nullptr);
  CefBoxLayoutSettings row;
  row.horizontal = true;
  row.between_child_spacing = 12;
  row.inside_border_insets = {6, 16, 6, 16};
  row.cross_axis_alignment = CEF_AXIS_ALIGNMENT_CENTER;
  banner->SetToBoxLayout(row);
  banner->SetBackgroundColor(CefColorSetARGB(255, 40, 40, 40));
  CefRefPtr<CefLabelButton> label = CefLabelButton::CreateLabelButton(
      buttons, "Something is playing in the pop-out. Play this page's video there instead?");
  label->SetID(BannerButtons::kLabel);
  label->SetEnabled(false);
  label->SetTextColor(CEF_BUTTON_STATE_DISABLED, CefColorSetARGB(255, 255, 255, 255));
  CefRefPtr<CefLabelButton> play = CefLabelButton::CreateLabelButton(buttons, "Play in pop-out");
  play->SetID(BannerButtons::kPlay);
  CefRefPtr<CefLabelButton> dismiss = CefLabelButton::CreateLabelButton(buttons, "Dismiss");
  dismiss->SetID(BannerButtons::kDismiss);
  banner->AddChildView(label);
  banner->AddChildView(play);
  banner->AddChildView(dismiss);
  banner->SetVisible(false);
  window->AddChildView(banner);

  // While something is popped out, a new page mustn't start playing over it:
  // create it blank, install the autoplay hold, then load it.
  std::string initial_url = url;
  if (popout_browser_) {
    held_page_urls_.push_back(url);
    initial_url = "about:blank";
  }
  CefBrowserSettings settings;
  CefRefPtr<CefBrowserView> view = CefBrowserView::CreateBrowserView(
      this, initial_url, settings, nullptr, nullptr, page_view_delegate_);
  window->AddChildView(view);
  layout->SetFlexForView(view, 1);

  pages_.push_back({window, banner, view});
  current_window_ = window;
  window->Show();
}

void SpikeClient::OnPageWindowActivated(CefRefPtr<CefWindow> window) {
  current_window_ = window;
}

bool SpikeClient::CanClosePageWindow(CefRefPtr<CefWindow> window) {
  Page* page = PageForWindow(window);
  CefRefPtr<CefBrowser> browser = page ? page->browser() : nullptr;
  // Lets the page run its unload handlers first (see cefsimple).
  return !browser || browser->GetHost()->TryCloseBrowser();
}

void SpikeClient::OnPageWindowDestroyed(CefRefPtr<CefWindow> window) {
  pages_.erase(std::remove_if(pages_.begin(), pages_.end(),
                              [&](const Page& page) { return page.window->IsSame(window); }),
               pages_.end());
  if (current_window_ && current_window_->IsSame(window)) {
    current_window_ = pages_.empty() ? nullptr : pages_.back().window;
  }
  if (pages_.empty()) {
    if (popout_browser_) popout_browser_->GetHost()->CloseBrowser(true);
    CefQuitMessageLoop();
  }
}

void SpikeClient::CloseAll() {
  quitting_ = true;
  if (popout_browser_) popout_browser_->GetHost()->CloseBrowser(false);
  for (const Page& page : std::vector<Page>(pages_)) page.window->Close();
  if (pages_.empty()) CefQuitMessageLoop();
}

SpikeClient::Page* SpikeClient::PageForWindow(CefRefPtr<CefWindow> window) {
  for (Page& page : pages_) {
    if (window && page.window->IsSame(window)) return &page;
  }
  return nullptr;
}

SpikeClient::Page* SpikeClient::PageForBrowser(CefRefPtr<CefBrowser> browser) {
  for (Page& page : pages_) {
    if (browser && page.browser() && page.browser()->IsSame(browser)) return &page;
  }
  return nullptr;
}

void SpikeClient::SetBannerVisible(Page* page, bool visible) {
  if (!page) return;
  page->banner->SetVisible(visible);
  page->window->Layout();
}

// --- Pop-out ----------------------------------------------------------------

std::string SpikeClient::SelectorJson() const {
  CefRefPtr<CefValue> selector = CefValue::Create();
  selector->SetString(selector_);
  return CefWriteJSON(selector, JSON_WRITER_DEFAULT).ToString();
}

void SpikeClient::RunPopoutScript(CefRefPtr<CefBrowser> page,
                                  bool play_after_move,
                                  const std::string& place) {
  std::string script = kPopoutScript;
  auto fill = [&](const std::string& placeholder, const std::string& value) {
    script.replace(script.find(placeholder), placeholder.size(), value);
  };
  fill("%SELECTOR%", SelectorJson());
  fill("%PLAY%", play_after_move ? "true" : "false");
  fill("%PLACE%", place);
  // Document PiP needs a user gesture; run it as one.
  Evaluate(page, script, /*user_gesture=*/true, nullptr);
}

void SpikeClient::TogglePopout() {
  if (popout_browser_) {
    popout_browser_->GetHost()->CloseBrowser(false);
    return;
  }
  Page* page = PageForWindow(current_window_);
  if (page && page->browser()) RunPopoutScript(page->browser(), false, "null");
}

void SpikeClient::PlayInPopout(CefRefPtr<CefWindow> window) {
  Page* page = PageForWindow(window);
  if (!page || !page->browser()) return;
  SetBannerVisible(page, false);
  if (!popout_browser_ || !popout_source_) {
    RunPopoutScript(page->browser(), true, "null");
    return;
  }
  // Note where the current pop-out is, close it (its element returns to its
  // own page), then pop out this page's player in the same place: see
  // OnBeforeClose.
  CefRefPtr<SpikeClient> self(this);
  CefRefPtr<CefBrowser> target = page->browser();
  Evaluate(popout_source_, kPopoutPlaceScript, false, [self, target](CefRefPtr<CefValue> place) {
    self->swap_place_ = place && place->GetType() == VTYPE_LIST
                            ? CefWriteJSON(place, JSON_WRITER_DEFAULT).ToString()
                            : "null";
    self->swap_target_ = target;
    self->swap_pending_ = true;
    if (self->popout_browser_) self->popout_browser_->GetHost()->CloseBrowser(false);
  });
}

void SpikeClient::DismissBanner(CefRefPtr<CefWindow> window) {
  SetBannerVisible(PageForWindow(window), false);
}

void SpikeClient::OfferIfPageHasPlayer(CefRefPtr<CefBrowser> page, int attempts_left) {
  if (!popout_browser_ || (popout_source_ && page->IsSame(popout_source_))) return;
  CefRefPtr<SpikeClient> self(this);
  Evaluate(page, "!!document.querySelector(" + SelectorJson() + ")", false,
           [self, page, attempts_left](CefRefPtr<CefValue> found) {
             if (found && found->GetType() == VTYPE_BOOL && found->GetBool()) {
               self->SetBannerVisible(self->PageForBrowser(page), true);
             } else if (attempts_left > 1) {
               // Players often appear after the page has loaded.
               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                 self->OfferIfPageHasPlayer(page, attempts_left - 1);
               });
             }
           });
}

// --- DevTools ---------------------------------------------------------------

void SpikeClient::DevTools(CefRefPtr<CefBrowser> page,
                           const std::string& method,
                           CefRefPtr<CefDictionaryValue> params,
                           std::function<void(CefRefPtr<CefDictionaryValue>)> callback) {
  const int id = page->GetHost()->ExecuteDevToolsMethod(0, method, params);
  if (id && callback) {
    pending_results_[{page->GetIdentifier(), id}] = std::move(callback);
  }
}

void SpikeClient::Evaluate(CefRefPtr<CefBrowser> page,
                           const std::string& expression,
                           bool user_gesture,
                           std::function<void(CefRefPtr<CefValue>)> callback) {
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("expression", expression);
  params->SetBool("returnByValue", true);
  if (user_gesture) params->SetBool("userGesture", true);
  if (!callback) {
    DevTools(page, "Runtime.evaluate", params, nullptr);
    return;
  }
  DevTools(page, "Runtime.evaluate", params, [callback](CefRefPtr<CefDictionaryValue> result) {
    // {"result": {"type": ..., "value": ...}}
    CefRefPtr<CefDictionaryValue> inner = result ? result->GetDictionary("result") : nullptr;
    callback(inner && inner->HasKey("value") ? inner->GetValue("value") : nullptr);
  });
}

void SpikeClient::OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser,
                                         int message_id,
                                         bool success,
                                         const void* result,
                                         size_t result_size) {
  auto it = pending_results_.find({browser->GetIdentifier(), message_id});
  if (it == pending_results_.end()) return;
  auto callback = std::move(it->second);
  pending_results_.erase(it);

  CefRefPtr<CefDictionaryValue> parsed_result;
  if (success) {
    CefRefPtr<CefValue> parsed = CefParseJSON(result, result_size, JSON_PARSER_RFC);
    parsed_result = parsed ? parsed->GetDictionary() : nullptr;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    callback(parsed_result);
  });
}

// --- Life span --------------------------------------------------------------

bool SpikeClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
  if (target_disposition == CEF_WOD_NEW_PICTURE_IN_PICTURE) {
    // The pop-out. CEF creates it (frameless, per PageViewDelegate); we keep
    // our client to follow its life span.
    popout_source_ = browser;
    return false;
  }
  // Links while popped out ("openp41ge-newpage") and any other new window:
  // open in a new page window (no real tabs in the spike).
  if (!target_url.empty()) OpenPageWindow(target_url);
  return true;
}

void SpikeClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (browser->IsPopup()) {
    popout_browser_ = browser;
    return;
  }
  devtools_registrations_[browser->GetIdentifier()] =
      browser->GetHost()->AddDevToolsMessageObserver(this);

  if (!held_page_urls_.empty()) {
    // Created blank (see OnPageWindowCreated): install the hold, then load
    // the page. The Page domain must be enabled for the script to be injected.
    const std::string url = held_page_urls_.front();
    held_page_urls_.erase(held_page_urls_.begin());
    CefRefPtr<SpikeClient> self(this);
    DevTools(browser, "Page.enable", CefDictionaryValue::Create(),
             [self, browser, url](CefRefPtr<CefDictionaryValue>) {
               CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
               params->SetString("source", kHoldAutoplayScript);
               self->DevTools(browser, "Page.addScriptToEvaluateOnNewDocument", params,
                              [browser, url](CefRefPtr<CefDictionaryValue>) {
                                browser->GetMainFrame()->LoadURL(url);
                              });
             });
  }
}

void SpikeClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  if (!browser->IsPopup()) {
    devtools_registrations_.erase(browser->GetIdentifier());
    return;
  }
  popout_browser_ = nullptr;
  // The element is back in its page. If that page was only kept open for the
  // pop-out (another page window is now in front), close it too.
  CefRefPtr<CefBrowser> source = popout_source_;
  popout_source_ = nullptr;
  Page* source_page = PageForBrowser(source);
  const bool source_in_front = source_page && current_window_ && source_page->window->IsSame(current_window_);
  if (source_page && !source_in_front && !quitting_ && pages_.size() > 1) {
    source_page->window->Close();
  }
  if (swap_pending_ && swap_target_) {
    swap_pending_ = false;
    // The user chose this video for the pop-out: play it there.
    RunPopoutScript(swap_target_, true, swap_place_);
    swap_target_ = nullptr;
  }
}

// --- Display / load ---------------------------------------------------------

void SpikeClient::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) {
  Page* page = PageForBrowser(browser);
  if (page) page->window->SetTitle(title);
}

void SpikeClient::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                       bool is_loading,
                                       bool can_go_back,
                                       bool can_go_forward) {
  if (!is_loading && !browser->IsPopup()) OfferIfPageHasPlayer(browser, 5);
}
