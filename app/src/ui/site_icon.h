// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_SITE_ICON_H_
#define OPENP41GE_EXPLORER_UI_SITE_ICON_H_

#include <string>

#include "include/cef_browser.h"
#include "include/cef_resource_handler.h"

// A site's best icon, for the start page's shortcuts: served at
// openp41ge://start/icon?url=<site>.
//
// The browser fetches the site's page, reads the icons it declares (<link
// rel="apple-touch-icon" | "icon"> and its web app manifest's), and returns
// the best of them: the smallest at least kGoodSize px, else a scalable (SVG)
// one, else the largest; then /apple-touch-icon.png and /favicon.ico. A 404
// if the site has none. (The start page can't read other sites' pages
// itself.)
namespace site_icon {

constexpr char kPath[] = "/icon";

// The handler for a request for `site`'s icon, made by `browser`'s page.
CefRefPtr<CefResourceHandler> CreateHandler(CefRefPtr<CefBrowser> browser, const std::string& site);

}  // namespace site_icon

#endif  // OPENP41GE_EXPLORER_UI_SITE_ICON_H_
