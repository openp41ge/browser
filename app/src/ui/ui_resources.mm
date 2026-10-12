// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_scheme.h"

#include <sstream>

#import <Foundation/Foundation.h>

#include "include/cef_parser.h"
#include "include/cef_stream.h"
#include "include/wrapper/cef_stream_resource_handler.h"
#include "ui/site_icon.h"

namespace ui_scheme {
namespace {

// Serves one host's files from Contents/Resources/<folder> (shared/ from
// Contents/Resources/shared); anything else is a 404. A folder's index.html
// is served for its root.
class UiResourceFactory : public CefSchemeHandlerFactory {
 public:
  // `index`: the file served for the folder's root.
  UiResourceFactory(NSString* folder, NSString* index) : folder_(folder), index_(index) {}

  CefRefPtr<CefResourceHandler> Create(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       const CefString& scheme_name,
                                       CefRefPtr<CefRequest> request) override {
    CefURLParts parts;
    if (!CefParseURL(request->GetURL(), parts)) return NotFound();
    if ([folder_ isEqualToString:@"start"] && CefString(&parts.path).ToString() == site_icon::kPath) {
      return SiteIcon(browser, frame, request, CefString(&parts.query));
    }
    NSString* path = @(CefString(&parts.path).ToString().c_str());
    NSString* folder = folder_;
    if ([path hasPrefix:@"/shared/"]) {
      folder = @"shared";
      path = [path substringFromIndex:@"/shared".length];
    }
    if ([path isEqualToString:@"/"]) path = index_;
    NSString* root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:folder];
    NSString* file = [[root stringByAppendingPathComponent:path] stringByStandardizingPath];
    // No "../" out of the UI folder.
    if (![file hasPrefix:[root stringByAppendingString:@"/"]]) return NotFound();
    CefRefPtr<CefStreamReader> reader = CefStreamReader::CreateForFile(file.UTF8String);
    if (!reader) return NotFound();
    return new CefStreamResourceHandler(CefGetMimeType(file.pathExtension.UTF8String), reader);
  }

 private:
  // icon?url=<site>, for the start page only (not a fetcher for any page).
  static CefRefPtr<CefResourceHandler> SiteIcon(CefRefPtr<CefBrowser> browser,
                                                CefRefPtr<CefFrame> frame,
                                                CefRefPtr<CefRequest> request,
                                                const std::string& query) {
    if (!frame || !frame->IsMain()) return NotFound();
    // The page asking. Just after it loads (e.g. reloaded), CEF may not have
    // recorded the frame's new URL yet, so it's empty: then the page its
    // requests are made for (set by the browser from the top-level page).
    const std::string page = frame->GetURL();
    if (!IsStartUrl(page.empty() ? request->GetFirstPartyForCookies().ToString() : page)) return NotFound();
    std::istringstream params(query);
    for (std::string param; std::getline(params, param, '&');) {
      if (param.rfind("url=", 0) != 0) continue;
      const std::string site =
          CefURIDecode(param.substr(4), true,
                       static_cast<cef_uri_unescape_rule_t>(UU_SPACES | UU_PATH_SEPARATORS |
                                                            UU_URL_SPECIAL_CHARS_EXCEPT_PATH_SEPARATORS |
                                                            UU_REPLACE_PLUS_WITH_SPACE));
      if (CefRefPtr<CefResourceHandler> handler = site_icon::CreateHandler(browser, site)) return handler;
    }
    return NotFound();
  }

  static CefRefPtr<CefResourceHandler> NotFound() {
    // With a body: CefStreamResourceHandler reads its stream unchecked.
    static constexpr char kBody[] = "Not Found";
    CefRefPtr<CefStreamReader> body = CefStreamReader::CreateForData(const_cast<char*>(kBody), sizeof(kBody) - 1);
    return new CefStreamResourceHandler(404, "Not Found", "text/plain", {}, body);
  }

  NSString* const folder_;
  NSString* const index_;

  IMPLEMENT_REFCOUNTING(UiResourceFactory);
};

}  // namespace

void RegisterHandlerFactory(CefRefPtr<CefRequestContext> context, bool is_private) {
  context = context ? context : CefRequestContext::GetGlobalContext();
  context->RegisterSchemeHandlerFactory(kScheme, "ui", new UiResourceFactory(@"ui", @"/index.html"));
  context->RegisterSchemeHandlerFactory(kScheme, "start",
                                        new UiResourceFactory(@"start", is_private ? @"/private.html" : @"/index.html"));
}

}  // namespace ui_scheme
