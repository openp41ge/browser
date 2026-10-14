// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_UI_SCHEME_H_
#define OPENP41GE_EXPLORER_UI_UI_SCHEME_H_

#include <string>

#include "include/cef_request_context.h"
#include "include/cef_scheme.h"

// The browser's own UI (e.g. the top bar) is web content served from the app
// bundle at openp41ge://ui/ (sources in app/ui). Only pages there get the
// message channel to the browser (see renderer_app.cc and TopBar), and web
// pages can't load them.
//
// The start page is served at openp41ge://start/ (app/ui/start), and About
// openp41ge explorer at openp41ge://about/ (app/ui/about): ordinary pages in
// tabs, with no channel. The Extensions page, openp41ge://extensions/
// (app/ui/extensions), is a page in a tab too, with the extension system's
// channel (ExtensionManager), which checks it's this page.
//
// Both serve app/ui/shared at shared/ (the theme, address parsing).
namespace ui_scheme {

constexpr char kScheme[] = "openp41ge";
constexpr char kOrigin[] = "openp41ge://ui/";
constexpr char kStartUrl[] = "openp41ge://start/";
constexpr char kAboutUrl[] = "openp41ge://about/";
constexpr char kExtensionsUrl[] = "openp41ge://extensions/";

// Registers the scheme. Every process must call this, from
// CefApp::OnRegisterCustomSchemes.
void Register(CefRawPtr<CefSchemeRegistrar> registrar);

// Whether `url` is one of the browser's own UI pages.
bool IsUiUrl(const std::string& url);
// Whether `url` (or origin) is the start page's.
bool IsStartUrl(const std::string& url);
// Whether `url` is the Extensions page's.
bool IsExtensionsUrl(const std::string& url);

// Serves openp41ge://ui/ and openp41ge://start/ from Contents/Resources, to
// pages in `context` (default: the global one). A private context's start
// page is start/private.html, which says what a private window keeps.
// Browser process, once CEF is initialized.
void RegisterHandlerFactory(CefRefPtr<CefRequestContext> context = nullptr, bool is_private = false);

}  // namespace ui_scheme

#endif  // OPENP41GE_EXPLORER_UI_UI_SCHEME_H_
