// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
#define OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_

#include <functional>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "include/cef_client.h"
#include "include/cef_devtools_message_observer.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_panel.h"
#include "include/views/cef_window.h"

// Page windows and the pop-out.
//
// - Each page is a Chrome-style browser view (Chrome's toolbar off) in its
//   own window: CEF allows one Chrome-style page per window.
// - The pop-out is a Document Picture-in-Picture window that the page script
//   opens and moves the element into. The browser view delegate makes it
//   frameless and lets the script place it.
// - While something is popped out, links open in a new page window so the
//   pop-out's page keeps running. If the new page has a player, a bar offers
//   to play it in the pop-out instead.
class SpikeClient : public CefClient,
                    public CefLifeSpanHandler,
                    public CefDisplayHandler,
                    public CefLoadHandler,
                    public CefDevToolsMessageObserver {
 public:
  SpikeClient(std::string url, std::string selector);

  // Opens the first page window.
  void Start();
  // Pops out the current page's element, or puts it back.
  void TogglePopout();
  // The bar's action: the pop-out switches to this window's page.
  void PlayInPopout(CefRefPtr<CefWindow> window);
  void DismissBanner(CefRefPtr<CefWindow> window);
  // Closes everything; the app quits once every window is gone.
  void CloseAll();

  // Page window hooks (from their CefWindowDelegate).
  void OnPageWindowCreated(CefRefPtr<CefWindow> window, const std::string& url);
  void OnPageWindowActivated(CefRefPtr<CefWindow> window);
  bool CanClosePageWindow(CefRefPtr<CefWindow> window);
  void OnPageWindowDestroyed(CefRefPtr<CefWindow> window);

  // CefClient:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }

  // CefLifeSpanHandler:
  bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
                     bool* no_javascript_access) override;
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  // CefDisplayHandler:
  void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override;

  // CefLoadHandler:
  void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                            bool is_loading,
                            bool can_go_back,
                            bool can_go_forward) override;

  // CefDevToolsMessageObserver:
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser,
                              int message_id,
                              bool success,
                              const void* result,
                              size_t result_size) override;

 private:
  struct Page {
    CefRefPtr<CefWindow> window;
    CefRefPtr<CefPanel> banner;
    CefRefPtr<CefBrowserView> view;
    CefRefPtr<CefBrowser> browser() const { return view ? view->GetBrowser() : nullptr; }
  };

  void OpenPageWindow(const std::string& url);
  Page* PageForWindow(CefRefPtr<CefWindow> window);
  Page* PageForBrowser(CefRefPtr<CefBrowser> browser);
  void SetBannerVisible(Page* page, bool visible);
  // `place` is the JSON for the script's PLACE ("null" or [x, y, width]).
  void RunPopoutScript(CefRefPtr<CefBrowser> page, bool play_after_move, const std::string& place);
  void OfferIfPageHasPlayer(CefRefPtr<CefBrowser> page, int attempts_left);
  std::string SelectorJson() const;

  // Calls a DevTools protocol method on the page; the callback gets the
  // parsed result (null on failure).
  void DevTools(CefRefPtr<CefBrowser> page,
                const std::string& method,
                CefRefPtr<CefDictionaryValue> params,
                std::function<void(CefRefPtr<CefDictionaryValue>)> callback);
  // Runs `expression` in the page (as a user gesture if asked); the callback
  // gets its value (or null).
  void Evaluate(CefRefPtr<CefBrowser> page,
                const std::string& expression,
                bool user_gesture,
                std::function<void(CefRefPtr<CefValue>)> callback);

  std::string start_url_;
  std::string selector_;
  CefRefPtr<CefBrowserViewDelegate> page_view_delegate_;

  std::vector<Page> pages_;
  CefRefPtr<CefWindow> current_window_;   // The last active page window.
  CefRefPtr<CefBrowser> popout_source_;   // The page whose element is popped out.
  CefRefPtr<CefBrowser> popout_browser_;  // The Document PiP window.
  bool swap_pending_ = false;
  CefRefPtr<CefBrowser> swap_target_;
  std::string swap_place_ = "null";

  // URLs of pages opened while something is popped out. They're created
  // blank, get the autoplay hold, then load (see OnAfterCreated).
  std::vector<std::string> held_page_urls_;

  std::map<int, CefRefPtr<CefRegistration>> devtools_registrations_;
  std::map<std::pair<int, int>, std::function<void(CefRefPtr<CefDictionaryValue>)>>
      pending_results_;
  bool quitting_ = false;

  IMPLEMENT_REFCOUNTING(SpikeClient);
};

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
