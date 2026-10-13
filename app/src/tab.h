// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_H_
#define OPENP41GE_EXPLORER_TAB_H_

#include <string>

#include "include/views/cef_browser_view.h"

// One tab: a web page (an Alloy-style browser view) and what its tab shows.
// It lives in a pane, whose active tab's view shows; the others are hidden
// in it (and still load and run).
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
  // The address last recorded in History (a reload isn't another visit).
  std::string visited;
  // Find in page: whether its find row is open, what it's finding, and the
  // matches (count, and which is the current one).
  bool finding = false;
  std::string find_text;
  int find_count = 0;
  int find_active = 0;

 private:
  int id_;
  CefRefPtr<CefBrowserView> view_;

  IMPLEMENT_REFCOUNTING(Tab);
};

#endif  // OPENP41GE_EXPLORER_TAB_H_
