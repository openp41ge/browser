// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_
#define OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_

#include <functional>
#include <memory>
#include <optional>
#include <string>

#include "include/cef_client.h"

#include "devtools_client.h"

// Element pop-out: moves a page element into its own window, as real DOM in
// the same page (see packages/popout/src/core.js for the page side).
//
// The window is a Document Picture-in-Picture window opened by the page:
// Chromium keeps media playing when elements move into one. The browser
// hosts it in its own frameless, floating window (PopoutWindow), placed over
// the element and kept to its shape, and moved and resized as the page asks
// (core.js writes the frame it wants on the pop-out's document); the page's
// -webkit-app-region: drag areas move it.
//
// One pop-out at a time. This is the API that the browser's own commands
// use and that the openp41ge link will use. Pop-outs that pages open
// themselves (any Document PiP request) get the same window.
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
  ~PopoutController() override;

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

  // From the pages' CefLifeSpanHandler::OnBeforePopup. For a Document PiP
  // request, creates our window for it, has CEF create the PiP page inside
  // it, gives it the pop-out's own client, and returns true.
  bool OnBeforePopup(CefRefPtr<CefBrowser> opener,
                     cef_window_open_disposition_t disposition,
                     CefWindowInfo& window_info,
                     CefRefPtr<CefClient>& client);

 private:
  class WindowClient;
  struct Native;  // The Cocoa window (popout_controller.mm).

  void OnWindowCreated(CefRefPtr<CefBrowser> window);
  void OnWindowClosed();
  // Moves our window over the element (asks the page where it is).
  void Place(int attempts_left);
  // While it's open, gives the window each new frame the page asks for
  // (core.js's requestFrame: a page can't move or resize a Document PiP
  // window itself without a user action).
  void WatchFrame();

  CefRefPtr<DevToolsClient> devtools_;
  Observer* observer_;
  CefRefPtr<CefClient> window_client_;
  std::unique_ptr<Native> native_;

  CefRefPtr<CefBrowser> pending_source_;  // Asked for a window, not created yet.
  CefRefPtr<CefBrowser> source_;          // The page whose element is popped out.
  CefRefPtr<CefBrowser> window_;          // The pop-out's page.

  IMPLEMENT_REFCOUNTING(PopoutController);
};

#endif  // OPENP41GE_EXPLORER_POPOUT_POPOUT_CONTROLLER_H_
