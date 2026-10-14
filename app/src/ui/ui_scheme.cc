// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_scheme.h"

namespace ui_scheme {

void Register(CefRawPtr<CefSchemeRegistrar> registrar) {
  // Standard (it has an origin and relative URLs work) and secure (like
  // https).
  registrar->AddCustomScheme(kScheme, CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE);
}

bool IsUiUrl(const std::string& url) {
  return url.rfind(kOrigin, 0) == 0;
}

bool IsExtensionsUrl(const std::string& url) {
  return url.rfind(kExtensionsUrl, 0) == 0;
}

bool IsStartUrl(const std::string& url) {
  // An origin has no trailing slash.
  const std::string origin(kStartUrl, sizeof(kStartUrl) - 2);
  return url.rfind(origin, 0) == 0 && (url.size() == origin.size() || url[origin.size()] == '/');
}

}  // namespace ui_scheme
