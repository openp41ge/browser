// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_UI_UI_SCHEME_H_
#define OPENP41GE_EXPLORER_UI_UI_SCHEME_H_

#include <string>

#include "include/cef_scheme.h"

// The browser's own UI (e.g. the top bar) is web content served from the app
// bundle at openp41ge://ui/ (sources in app/ui). Only pages there get the
// message channel to the browser (see renderer_app.cc and TopBar).
namespace ui_scheme {

constexpr char kScheme[] = "openp41ge";
constexpr char kOrigin[] = "openp41ge://ui/";

// Registers the scheme. Every process must call this, from
// CefApp::OnRegisterCustomSchemes.
void Register(CefRawPtr<CefSchemeRegistrar> registrar);

// Whether `url` is one of the browser's own UI pages.
bool IsUiUrl(const std::string& url);

// Serves openp41ge://ui/ from Contents/Resources/ui. Browser process, once
// CEF is initialized.
void RegisterHandlerFactory();

}  // namespace ui_scheme

#endif  // OPENP41GE_EXPLORER_UI_UI_SCHEME_H_
