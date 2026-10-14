// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/extension_scheme.h"

#include <filesystem>
#include <set>

#include "include/cef_parser.h"
#include "include/cef_request_context.h"
#include "include/cef_stream.h"
#include "include/wrapper/cef_stream_resource_handler.h"

namespace extension_scheme {

namespace {

namespace fs = std::filesystem;

constexpr char kPolicy[] =
    "default-src 'self'; script-src 'self'; object-src 'none'; style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: https:; media-src 'self' https:; connect-src 'self' https:; frame-ancestors 'none'";

// One extension's files. Fixed once made (it's used on the IO thread).
class Files : public CefSchemeHandlerFactory {
 public:
  explicit Files(const Extension& extension) : folder_(fs::path(extension.folder)) {
    for (const Extension::Page& page : extension.pages) pages_.insert("/" + page.path);
  }

  CefRefPtr<CefResourceHandler> Create(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       const CefString& scheme_name,
                                       CefRefPtr<CefRequest> request) override {
    CefURLParts parts;
    if (!CefParseURL(request->GetURL(), parts)) return NotFound();
    const std::string path = CefURIDecode(CefString(&parts.path), true, UU_SPACES).ToString();
    switch (request->GetResourceType()) {
      case RT_MAIN_FRAME:
        // Only the manifest's pages are pages.
        if (!pages_.count(path)) return NotFound();
        break;
      case RT_SUB_FRAME:
        return NotFound();
      default:
        break;
    }
    // A file in the folder (also once links are followed).
    std::error_code error;
    const fs::path file = fs::canonical(folder_ / fs::path(path).relative_path(), error);
    if (error || file.string().rfind((folder_ / "").string(), 0) != 0 || !fs::is_regular_file(file)) {
      return NotFound();
    }
    CefRefPtr<CefStreamReader> reader = CefStreamReader::CreateForFile(file.string());
    if (!reader) return NotFound();
    std::string extension = file.extension().string();
    if (!extension.empty()) extension.erase(0, 1);
    std::string mime = CefGetMimeType(extension).ToString();
    if (mime.empty()) mime = "application/octet-stream";
    CefResponse::HeaderMap headers;
    headers.insert({"Content-Security-Policy", kPolicy});
    headers.insert({"Cross-Origin-Resource-Policy", "same-origin"});
    headers.insert({"X-Content-Type-Options", "nosniff"});
    headers.insert({"Cache-Control", "no-store"});
    return new CefStreamResourceHandler(200, "OK", mime, headers, reader);
  }

 private:
  static CefRefPtr<CefResourceHandler> NotFound() {
    // With a body: CefStreamResourceHandler reads its stream unchecked.
    static constexpr char kBody[] = "Not Found";
    CefRefPtr<CefStreamReader> body = CefStreamReader::CreateForData(const_cast<char*>(kBody), sizeof(kBody) - 1);
    return new CefStreamResourceHandler(404, "Not Found", "text/plain", {}, body);
  }

  const fs::path folder_;  // Canonical.
  std::set<std::string> pages_;

  IMPLEMENT_REFCOUNTING(Files);
};

}  // namespace

void Register(CefRawPtr<CefSchemeRegistrar> registrar) {
  // Standard (an origin of each id, relative URLs), secure (like https),
  // and fetch() and modules work in it.
  registrar->AddCustomScheme(kScheme, CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE |
                                          CEF_SCHEME_OPTION_CORS_ENABLED | CEF_SCHEME_OPTION_FETCH_ENABLED);
}

std::string Origin(const std::string& id) {
  return std::string(kScheme) + "://" + id;
}

std::string IdOf(const std::string& url) {
  const std::string prefix = std::string(kScheme) + "://";
  if (url.rfind(prefix, 0) != 0) return std::string();
  const size_t end = url.find_first_of("/?#:", prefix.size());
  return url.substr(prefix.size(), end == std::string::npos ? std::string::npos : end - prefix.size());
}

void Serve(const Extension& extension) {
  CefRequestContext::GetGlobalContext()->RegisterSchemeHandlerFactory(kScheme, extension.id, new Files(extension));
}

}  // namespace extension_scheme
