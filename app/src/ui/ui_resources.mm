// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_live_reload.h"
#include "ui/ui_scheme.h"

#include <algorithm>
#include <cstring>
#include <sstream>

#import <Foundation/Foundation.h>

#include "include/cef_parser.h"
#include "include/cef_stream.h"
#include "include/cef_version.h"
#include "include/wrapper/cef_stream_resource_handler.h"
#include "tab_previews.h"
#include "ui/site_icon.h"

namespace ui_scheme {
namespace {

// Serves one host's files from Contents/Resources/<folder> (shared/ from
// Contents/Resources/shared); anything else is a 404. A folder's index.html
// is served for its root.
// A stream of a string it keeps.
class StringReader : public CefReadHandler {
 public:
  explicit StringReader(std::string data) : data_(std::move(data)) {}

  size_t Read(void* ptr, size_t size, size_t n) override {
    const size_t count = std::min(n, (data_.size() - offset_) / (size ? size : 1));
    memcpy(ptr, data_.data() + offset_, count * size);
    offset_ += count * size;
    return count;
  }
  int Seek(int64_t offset, int whence) override {
    const int64_t base = whence == SEEK_CUR ? offset_ : whence == SEEK_END ? data_.size() : 0;
    if (base + offset < 0 || base + offset > static_cast<int64_t>(data_.size())) return -1;
    offset_ = static_cast<size_t>(base + offset);
    return 0;
  }
  int64_t Tell() override { return offset_; }
  int Eof() override { return offset_ >= data_.size(); }
  bool MayBlock() override { return false; }

 private:
  std::string data_;
  size_t offset_ = 0;

  IMPLEMENT_REFCOUNTING(StringReader);
};

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
    if ([folder_ isEqualToString:@"about"] && [path isEqualToString:@"/info.js"]) return AboutInfo();
    if ([folder_ isEqualToString:@"ui"] && [path hasPrefix:@"/preview/"]) return Preview(path);
    NSString* folder = folder_;
    if ([path hasPrefix:@"/shared/"]) {
      folder = @"shared";
      path = [path substringFromIndex:@"/shared".length];
    }
    if ([path isEqualToString:@"/"]) path = index_;
    NSString* root = Root(folder);
    NSString* file = [[root stringByAppendingPathComponent:path] stringByStandardizingPath];
    // No "../" out of the UI folder.
    if (![file hasPrefix:[root stringByAppendingString:@"/"]]) return NotFound();
    CefRefPtr<CefStreamReader> reader = CefStreamReader::CreateForFile(file.UTF8String);
    // A development build serves from the checkout, which hasn't anything
    // copied into the bundle from elsewhere in the repository.
    if (!reader) {
      NSString* bundled = [[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:folder]
          stringByAppendingPathComponent:path].stringByStandardizingPath;
      if ([bundled hasPrefix:[NSBundle.mainBundle.resourcePath stringByAppendingString:@"/"]]) {
        reader = CefStreamReader::CreateForFile(bundled.UTF8String);
      }
    }
    if (!reader) return NotFound();
    return new CefStreamResourceHandler(CefGetMimeType(file.pathExtension.UTF8String), reader);
  }

  // openp41ge://about/info.js: what About shows, as a module (the page has no
  // channel to ask).
  static CefRefPtr<CefResourceHandler> AboutInfo() {
    NSDictionary* plist = NSBundle.mainBundle.infoDictionary;
    NSString* channel = plist[@"ExplorerChannel"] ?: @"dev";
    NSDictionary* info = @{
      @"version" : plist[@"CFBundleShortVersionString"] ?: @"",
      @"build" : plist[@"CFBundleVersion"] ?: @"",
      @"channel" : channel,
      @"cef" : [@(CEF_VERSION) componentsSeparatedByString:@"+"].firstObject,
      @"chromium" : [NSString stringWithFormat:@"%d.%d.%d.%d", CHROME_VERSION_MAJOR, CHROME_VERSION_MINOR,
                                               CHROME_VERSION_BUILD, CHROME_VERSION_PATCH],
    };
    NSData* json = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
    std::string body = "export default " + std::string(static_cast<const char*>(json.bytes), json.length) + ";\n";
    return new CefStreamResourceHandler("text/javascript",
                                        CefStreamReader::CreateForHandler(new StringReader(std::move(body))));
  }

 private:
  // preview/<token>.jpg: a tab's picture (tab_previews.h), for the tab bars.
  static CefRefPtr<CefResourceHandler> Preview(NSString* path) {
    NSString* name = path.lastPathComponent;
    if (![name.pathExtension isEqualToString:@"jpg"]) return NotFound();
    std::string jpeg = tab_previews::Get(name.stringByDeletingPathExtension.UTF8String);
    if (jpeg.empty()) return NotFound();
    return new CefStreamResourceHandler("image/jpeg", CefStreamReader::CreateForHandler(new StringReader(std::move(jpeg))));
  }

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

  // Where `folder`'s files are: Contents/Resources/<folder>, or in a
  // development build the checkout's app/ui (ui) or app/ui/<folder>.
  static NSString* Root(NSString* folder) {
    const std::string source = ui_live_reload::SourceDir();
    if (source.empty()) return [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:folder];
    NSString* dir = @(source.c_str());
    return [folder isEqualToString:@"ui"] ? dir : [dir stringByAppendingPathComponent:folder];
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
  context->RegisterSchemeHandlerFactory(kScheme, "about", new UiResourceFactory(@"about", @"/index.html"));
}

}  // namespace ui_scheme
