// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_SCHEME_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_SCHEME_H_

#include <string>

#include "include/cef_scheme.h"

#include "extensions/extension.h"

// Extension pages: openp41ge-extension://<id>/<path>, served from the
// extension's folder. Each extension is an origin of its own, apart from
// web pages and from the browser's UI (openp41ge://ui/). See
// plans/2026-10-14-extension-system.md, "Extension pages".
//
// - A page (a document in a tab) is only one the manifest lists in
//   `pages`; the files those pages load (scripts, styles, images) are any
//   in the folder.
// - /_openp41ge/ is the browser's, in every extension's origin: its
//   settings page for the extension, if it has settings
//   (/_openp41ge/settings.html, from
//   app/ui/extension-settings, and /_openp41ge/shared/ from app/ui/shared),
//   which so has the extension's `openp41ge`.
// - Served with a content security policy that lets pages run only their
//   own extension's scripts (no inline or remote ones), and not be framed;
//   and with Cross-Origin-Resource-Policy: same-origin, so web pages can't
//   load the extension's files.
namespace extension_scheme {

constexpr char kScheme[] = "openp41ge-extension";
// The browser's files in each extension's origin (a manifest can't use it).
constexpr char kBrowserFolder[] = "_openp41ge";
constexpr char kSettingsPage[] = "_openp41ge/settings.html";

// Registers the scheme. Every process must call this, from
// CefApp::OnRegisterCustomSchemes.
void Register(CefRawPtr<CefSchemeRegistrar> registrar);

// `extension`'s origin, openp41ge-extension://<id> (no trailing slash).
std::string Origin(const std::string& id);

// The extension id in `url`, if it's an extension page's; else empty.
std::string IdOf(const std::string& url);

// The browser's settings page for extension `id`.
std::string SettingsUrl(const std::string& id);

// Serves `extension`'s files, and the browser's from `resources` (the app
// bundle's Resources folder), in the global request context.
// Browser process, once CEF is initialized.
void Serve(const Extension& extension, const std::string& resources);

}  // namespace extension_scheme

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_SCHEME_H_
