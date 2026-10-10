// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
#define OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_

#import <Cocoa/Cocoa.h>

#include <string>

#include "include/cef_client.h"

@class SpikeWindowDelegate;

// Callbacks for the main page and its pop-out child window.
//
// When the page opens a child window named "openp41ge-popout:x,y,w,h",
// OnBeforePopup creates it inside our own native window: floating, placed
// over the element's on-screen rect and locked to its aspect ratio.
class SpikeClient : public CefClient, public CefLifeSpanHandler, public CefDisplayHandler {
 public:
  SpikeClient(NSWindow* main_window, NSView* main_view, std::string selector);

  // Moves the element into a pop-out window, or puts it back.
  void TogglePopout();
  // Closes the pop-out (if any), then the page; the app quits afterwards.
  void CloseAll();
  // Our NSWindows' close buttons route through here, so the browser closes
  // first. Returns whether the window may close now.
  bool WindowShouldClose(NSWindow* window);

  // CefClient:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }

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

 private:
  NSWindow* main_window_;
  NSView* main_view_;
  std::string selector_;
  CefRefPtr<CefBrowser> main_browser_;
  CefRefPtr<CefBrowser> popout_browser_;
  NSWindow* popout_window_ = nil;  // Created in OnBeforePopup.
  SpikeWindowDelegate* window_delegate_;
  bool main_closing_ = false;
  bool popout_closing_ = false;
  bool quitting_ = false;

  IMPLEMENT_REFCOUNTING(SpikeClient);
};

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_SPIKE_CLIENT_H_
