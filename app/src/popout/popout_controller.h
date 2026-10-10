// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_
#define OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_

#include <functional>
#include <optional>
#include <string>

#include "include/cef_client.h"

#include "devtools_client.h"

// Element pop-out: moves a page element into its own window, as real DOM in
// the same page (see app/resources/popout/core.js for the page side).
//
// The window is a Document Picture-in-Picture window opened by the page.
// Chromium keeps media playing when elements move into it, and the page
// view's delegate makes it frameless and lets the page script place it
// (CefBrowserViewDelegate's PiP options).
//
// One pop-out at a time. This is the API that the browser's own commands
// use and that the openp41ge link will use. Pop-outs that pages or
// extensions open themselves (any Document PiP window) are followed too, so
// the browser's handling below applies to them as well.
class PopoutController : public virtual CefBaseRefCounted {
 public:
  class Observer {
   public:
    virtual ~Observer() = default;
    // `source` is the page the popped-out element belongs to.
    virtual void OnPopoutOpened(CefRefPtr<CefBrowser> source) {}
    virtual void OnPopoutClosed(CefRefPtr<CefBrowser> source) {}
  };

  // Where a pop-out window sits on screen; its height follows the element.
  struct Place {
    int x = 0;
    int y = 0;
    int width = 0;
  };

  struct Options {
    // CSS selector of the element. Empty: the page's largest visible video
    // (preferring a playing one).
    std::string selector;
    // Start the element's media after the move.
    bool play = false;
    // Where to open; by default right over the element.
    std::optional<Place> place;
  };

  // "opened", "already-open", "nothing-to-pop-out" or "refused" (the page
  // didn't allow the window), or "failed" if the script didn't run.
  using DoneCallback = std::function<void(const std::string& outcome)>;

  PopoutController(CefRefPtr<DevToolsClient> devtools, Observer* observer);

  // Pops out an element of `page`.
  void PopOut(CefRefPtr<CefBrowser> page, const Options& options, DoneCallback done = nullptr);
  // Closes the pop-out; its element goes back into its page.
  void Close();
  // Pops out `page`'s default element, or closes the pop-out if one is open.
  void Toggle(CefRefPtr<CefBrowser> page);

  bool IsOpen() const { return window_ != nullptr; }
  CefRefPtr<CefBrowser> source() const { return source_; }

  // Script that pages created while something is popped out should run
  // before their own scripts (holds autoplay), or empty.
  std::string ScriptForNewPages() const;

  // From the pages' CefLifeSpanHandler::OnBeforePopup. Returns true if the
  // popup is a pop-out window (a Document PiP window, whoever opened it),
  // and gives it the pop-out's own client.
  bool OnBeforePopup(CefRefPtr<CefBrowser> opener,
                     cef_window_open_disposition_t disposition,
                     CefRefPtr<CefClient>& client);

 private:
  class WindowClient;

  void OnWindowCreated(CefRefPtr<CefBrowser> window);
  void OnWindowClosed();

  CefRefPtr<DevToolsClient> devtools_;
  Observer* observer_;
  CefRefPtr<CefClient> window_client_;

  CefRefPtr<CefBrowser> pending_source_;  // Asked for a window, not created yet.
  CefRefPtr<CefBrowser> source_;          // The page whose element is popped out.
  CefRefPtr<CefBrowser> window_;          // The pop-out window.

  IMPLEMENT_REFCOUNTING(PopoutController);
};

#endif  // OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_
