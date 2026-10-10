// Copyright (c) 2026 Richard Kielty. MIT License.

#include "page_window.h"

#include "include/views/cef_fill_layout.h"

#include "browser_manager.h"

CefBrowserViewDelegate::ChromeToolbarType PageViewDelegate::GetChromeToolbarType(
    CefRefPtr<CefBrowserView> view) {
  // Chrome's toolbar (back, forward, reload, address bar) keeps the browser
  // usable until our own UI replaces it (PLAN.md, Phase 3).
  return CEF_CTT_NORMAL;
}

bool PageViewDelegate::OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> view,
                                                 CefRefPtr<CefBrowserView> popup_view,
                                                 bool is_devtools) {
  if (is_devtools) return false;  // CEF's own window.
  manager_->OpenPageWindow(popup_view);
  return true;
}

PageWindow::PageWindow(BrowserManager* manager, CefRefPtr<CefBrowserView> view, CefRect bounds)
    : manager_(manager), view_(view), bounds_(bounds) {}

void PageWindow::OnWindowCreated(CefRefPtr<CefWindow> window) {
  window_ = window;
  window->SetToFillLayout();
  window->AddChildView(view_);
  manager_->OnPageWindowCreated(this);
  window->Show();
  view_->RequestFocus();
}

void PageWindow::OnWindowActivationChanged(CefRefPtr<CefWindow> window, bool active) {
  if (active) manager_->OnPageWindowActivated(this);
}

bool PageWindow::CanClose(CefRefPtr<CefWindow> window) {
  // Let the page run its unload handlers first (see cefsimple).
  CefRefPtr<CefBrowser> page = browser();
  return !page || page->GetHost()->TryCloseBrowser();
}

void PageWindow::OnWindowDestroyed(CefRefPtr<CefWindow> window) {
  manager_->OnPageWindowDestroyed(this);
  view_ = nullptr;
  window_ = nullptr;
}
