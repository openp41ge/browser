// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_H_
#define OPENP41GE_EXPLORER_TAB_H_

#include <string>

#include "include/views/cef_browser_view.h"

// One tab: a web page (an Alloy-style browser view) and what its tab shows.
// It lives in a pane; only the pane's active tab's view is in the window,
// the others are kept alive outside it.
class Tab : public CefBaseRefCounted {
 public:
  Tab(int id, CefRefPtr<CefBrowserView> view) : id_(id), view_(view) {}

  int id() const { return id_; }
  CefRefPtr<CefBrowserView> view() const { return view_; }
  CefRefPtr<CefBrowser> browser() const { return view_ ? view_->GetBrowser() : nullptr; }

  std::string title;
  std::string url;
  std::string favicon;
  bool loading = false;

 private:
  int id_;
  CefRefPtr<CefBrowserView> view_;

  IMPLEMENT_REFCOUNTING(Tab);
};

#endif  // OPENP41GE_EXPLORER_TAB_H_
