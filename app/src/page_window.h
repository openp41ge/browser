// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_PAGE_WINDOW_H_
#define OPENP41GE_EXPLORER_PAGE_WINDOW_H_

#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"

class BrowserManager;

// Delegate for every page's browser view: Chrome style with Chrome's
// toolbar (until the browser has its own UI), and pop-out windows that are
// frameless and placeable by the page's script.
class PageViewDelegate : public CefBrowserViewDelegate {
 public:
  explicit PageViewDelegate(BrowserManager* manager) : manager_(manager) {}

  cef_runtime_style_t GetBrowserRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
  ChromeToolbarType GetChromeToolbarType(CefRefPtr<CefBrowserView> view) override;
  bool UseFramelessWindowForPictureInPicture(CefRefPtr<CefBrowserView> view) override { return true; }
  bool AllowMoveForPictureInPicture(CefRefPtr<CefBrowserView> view) override { return true; }

  // Popups (window.open, links to new windows) become page windows too.
  CefRefPtr<CefBrowserViewDelegate> GetDelegateForPopupBrowserView(CefRefPtr<CefBrowserView> view,
                                                                   const CefBrowserSettings& settings,
                                                                   CefRefPtr<CefClient> client,
                                                                   bool is_devtools) override {
    return this;
  }
  bool OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> view,
                                 CefRefPtr<CefBrowserView> popup_view,
                                 bool is_devtools) override;

 private:
  BrowserManager* manager_;  // Lives as long as the app.
  IMPLEMENT_REFCOUNTING(PageViewDelegate);
};

// A top-level window holding one page's browser view. CEF allows one
// Chrome-style browser view per window, hence one page per window for now.
class PageWindow : public CefWindowDelegate {
 public:
  PageWindow(BrowserManager* manager, CefRefPtr<CefBrowserView> view, CefRect bounds);

  CefRefPtr<CefWindow> window() const { return window_; }
  CefRefPtr<CefBrowserView> view() const { return view_; }
  CefRefPtr<CefBrowser> browser() const { return view_ ? view_->GetBrowser() : nullptr; }

  // CefWindowDelegate:
  void OnWindowCreated(CefRefPtr<CefWindow> window) override;
  void OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) override;
  bool CanClose(CefRefPtr<CefWindow> window) override;
  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override;
  cef_runtime_style_t GetWindowRuntimeStyle() override { return CEF_RUNTIME_STYLE_CHROME; }
  CefRect GetInitialBounds(CefRefPtr<CefWindow> window) override { return bounds_; }

 private:
  BrowserManager* manager_;  // Lives as long as the app.
  CefRefPtr<CefBrowserView> view_;
  CefRect bounds_;
  CefRefPtr<CefWindow> window_;

  IMPLEMENT_REFCOUNTING(PageWindow);
};

#endif  // OPENP41GE_EXPLORER_PAGE_WINDOW_H_
