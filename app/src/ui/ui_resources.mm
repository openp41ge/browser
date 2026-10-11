// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_scheme.h"

#import <Foundation/Foundation.h>

#include "include/cef_parser.h"
#include "include/cef_stream.h"
#include "include/wrapper/cef_stream_resource_handler.h"

namespace ui_scheme {
namespace {

// Serves files from Contents/Resources/ui; anything else is a 404.
class UiResourceFactory : public CefSchemeHandlerFactory {
 public:
  CefRefPtr<CefResourceHandler> Create(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       const CefString& scheme_name,
                                       CefRefPtr<CefRequest> request) override {
    CefURLParts parts;
    if (!CefParseURL(request->GetURL(), parts)) return NotFound();
    NSString* path = @(CefString(&parts.path).ToString().c_str());
    NSString* root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"ui"];
    NSString* file = [[root stringByAppendingPathComponent:path] stringByStandardizingPath];
    // No "../" out of the UI folder.
    if (![file hasPrefix:[root stringByAppendingString:@"/"]]) return NotFound();
    CefRefPtr<CefStreamReader> reader = CefStreamReader::CreateForFile(file.UTF8String);
    if (!reader) return NotFound();
    return new CefStreamResourceHandler(CefGetMimeType(file.pathExtension.UTF8String), reader);
  }

 private:
  static CefRefPtr<CefResourceHandler> NotFound() {
    return new CefStreamResourceHandler(404, "Not Found", "text/plain", {}, nullptr);
  }

  IMPLEMENT_REFCOUNTING(UiResourceFactory);
};

}  // namespace

void RegisterHandlerFactory() {
  CefRegisterSchemeHandlerFactory(kScheme, "ui", new UiResourceFactory());
}

}  // namespace ui_scheme
