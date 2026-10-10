// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
#define OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_

#import <Cocoa/Cocoa.h>

#include <functional>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "include/cef_client.h"
#include "include/cef_devtools_message_observer.h"

@class SpikeBanner;
@class SpikeWindowDelegate;

// Pages in the main window (a minimal stand-in for tabs), and the pop-out.
//
// - The page script opens a child window named "openp41ge-popout:x,y,w,h";
//   OnBeforePopup creates it in our own floating window over the element.
// - While something is popped out, links open as new pages
//   ("openp41ge-newpage") so the popped-out video keeps playing in its own,
//   now hidden, page.
// - If a new page has a player, a bar offers to play it in the pop-out
//   instead. Nothing changes until the user clicks it.
class SpikeClient : public CefClient,
                    public CefLifeSpanHandler,
                    public CefDisplayHandler,
                    public CefLoadHandler,
                    public CefDevToolsMessageObserver {
 public:
  SpikeClient(NSWindow* main_window, NSView* main_view, std::string selector);

  // Opens a page in the main window and shows it.
  void CreatePage(const std::string& url);
  // Pops out the current page's element, or puts it back.
  void TogglePopout();
  // The bar's action: the pop-out switches to the current page's player.
  void PlayCurrentPageInPopout();
  void DismissBanner();
  // Closes everything; the app quits once all browsers are gone.
  void CloseAll();
  // Our NSWindows' close buttons route through here, so browsers close
  // first. Returns whether the window may close now.
  bool WindowShouldClose(NSWindow* window);

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
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
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
  NSView* ViewFor(CefRefPtr<CefBrowser> browser) const;
  void ShowPage(CefRefPtr<CefBrowser> page);
  void ClosePage(CefRefPtr<CefBrowser> page);
  void RunPopoutScript(CefRefPtr<CefBrowser> page);
  // Runs `expression` in the page; calls back with its boolean result.
  void Evaluate(CefRefPtr<CefBrowser> page,
                const std::string& expression,
                bool user_gesture,
                std::function<void(bool)> callback);
  // Offers the bar if the current page has a player (retries while it loads).
  void OfferIfPageHasPlayer(CefRefPtr<CefBrowser> page, int attempts_left);
  std::string SelectorJson() const;

  NSWindow* main_window_;
  NSView* main_view_;
  std::string selector_;
  SpikeWindowDelegate* window_delegate_;
  SpikeBanner* banner_;

  std::vector<CefRefPtr<CefBrowser>> pages_;
  CefRefPtr<CefBrowser> current_page_;
  CefRefPtr<CefBrowser> popout_source_;  // The page whose element is popped out.
  CefRefPtr<CefBrowser> popout_browser_;
  NSWindow* popout_window_ = nil;        // Created in OnBeforePopup.
  bool popout_closing_ = false;

  // Swapping the pop-out to another page's player: the new pop-out reuses
  // the current one's place and width.
  bool swap_pending_ = false;
  NSRect swap_content_rect_ = NSZeroRect;

  std::map<int, CefRefPtr<CefRegistration>> devtools_registrations_;
  std::map<std::pair<int, int>, std::function<void(bool)>> pending_results_;
  bool quitting_ = false;

  IMPLEMENT_REFCOUNTING(SpikeClient);
};

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
