// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/site_icon.h"

#include <CommonCrypto/CommonDigest.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iterator>
#include <set>
#include <utility>
#include <vector>

#include "include/base/cef_callback.h"
#include "include/cef_parser.h"
#include "include/cef_request_context.h"
#include "include/cef_urlrequest.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

namespace site_icon {
namespace {

// Icons are shown at 28pt (56px on a Retina screen); a little larger leaves
// room to scale down cleanly.
constexpr int kGoodSize = 96;
// Where the site's icons are declared: its page's <head>, and its manifest.
constexpr size_t kMaxPage = 512 * 1024;
constexpr size_t kMaxManifest = 256 * 1024;
constexpr size_t kMaxIcon = 4 * 1024 * 1024;

std::string Lower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
  return s;
}

std::vector<std::string> Words(const std::string& s) {
  std::vector<std::string> words;
  std::string word;
  for (char c : s + ' ') {
    if (std::isspace(static_cast<unsigned char>(c))) {
      if (!word.empty()) words.push_back(Lower(word));
      word.clear();
    } else {
      word += c;
    }
  }
  return words;
}

// --- Candidates ---------------------------------------------------------------

struct Candidate {
  std::string url;
  int size = 0;  // Largest side in px; 0 if unknown.
  bool scalable = false;
};

// Best first: the smallest of those at least kGoodSize, then scalable ones,
// then the largest of the rest, then unknown sizes (in the order found).
bool Better(const Candidate& a, const Candidate& b) {
  auto tier = [](const Candidate& c) { return c.size >= kGoodSize ? 0 : c.scalable ? 1 : c.size > 0 ? 2 : 3; };
  if (tier(a) != tier(b)) return tier(a) < tier(b);
  if (tier(a) == 0) return a.size < b.size;
  if (tier(a) == 2) return a.size > b.size;
  return false;
}

// "16x16 180x180" -> 180; "any" -> scalable.
void ReadSizes(const std::string& sizes, Candidate& c) {
  for (const std::string& size : Words(sizes)) {
    if (size == "any") {
      c.scalable = true;
      continue;
    }
    const size_t x = size.find('x');
    if (x == std::string::npos) continue;
    c.size = std::max(c.size, std::max(std::atoi(size.c_str()), std::atoi(size.c_str() + x + 1)));
  }
}

bool LooksLikeSvg(const std::string& url, const std::string& type) {
  const std::string path = Lower(url.substr(0, url.find_first_of("?#")));
  return Lower(type) == "image/svg+xml" || (path.size() > 4 && path.compare(path.size() - 4, 4, ".svg") == 0);
}

// --- URLs ---------------------------------------------------------------------

// `ref` (from a page or manifest at `base`) as an absolute URL. Chromium
// tidies the result (dot segments and so on) when it's requested.
std::string Resolve(const std::string& base, const std::string& ref) {
  if (ref.empty()) return {};
  size_t i = 0;
  while (i < ref.size() && (std::isalnum(static_cast<unsigned char>(ref[i])) || ref[i] == '+' || ref[i] == '-' || ref[i] == '.')) ++i;
  if (i > 0 && i < ref.size() && ref[i] == ':' && std::isalpha(static_cast<unsigned char>(ref[0]))) return ref;

  CefURLParts parts;
  if (!CefParseURL(base, parts)) return {};
  const std::string scheme = CefString(&parts.scheme).ToString();
  std::string origin = CefString(&parts.origin).ToString();
  if (!origin.empty() && origin.back() == '/') origin.pop_back();
  if (ref.rfind("//", 0) == 0) return scheme + ":" + ref;
  if (ref[0] == '/') return origin + ref;
  const std::string path = CefString(&parts.path).ToString();
  if (ref[0] == '?') return origin + path + ref;
  return origin + path.substr(0, path.rfind('/') + 1) + ref;
}

std::string OriginOf(const std::string& url) {
  CefURLParts parts;
  if (!CefParseURL(url, parts)) return {};
  std::string origin = CefString(&parts.origin).ToString();
  if (!origin.empty() && origin.back() == '/') origin.pop_back();
  return origin;
}

bool IsWeb(const std::string& url) {
  return url.rfind("https://", 0) == 0 || url.rfind("http://", 0) == 0;
}

// --- The page's <link>s -------------------------------------------------------

std::string DecodeEntities(std::string s) {
  static const std::pair<const char*, const char*> kEntities[] = {
      {"&amp;", "&"}, {"&quot;", "\""}, {"&#39;", "'"}, {"&#x27;", "'"}, {"&#x2F;", "/"}, {"&#47;", "/"}};
  for (const auto& [entity, text] : kEntities) {
    for (size_t at = s.find(entity); at != std::string::npos; at = s.find(entity, at + 1)) {
      s.replace(at, std::char_traits<char>::length(entity), text);
    }
  }
  return s;
}

// The attributes of the tag whose name ends at `at`, up to its '>'.
std::vector<std::pair<std::string, std::string>> Attributes(const std::string& html, size_t at) {
  std::vector<std::pair<std::string, std::string>> attributes;
  const auto space = [&](size_t i) { return i < html.size() && std::isspace(static_cast<unsigned char>(html[i])); };
  while (at < html.size() && html[at] != '>') {
    while (space(at) || (at < html.size() && html[at] == '/')) ++at;
    size_t name_end = at;
    while (name_end < html.size() && !space(name_end) && html[name_end] != '=' && html[name_end] != '>' &&
           html[name_end] != '/') {
      ++name_end;
    }
    if (name_end == at) break;
    std::string name = Lower(html.substr(at, name_end - at));
    at = name_end;
    while (space(at)) ++at;
    std::string value;
    if (at < html.size() && html[at] == '=') {
      ++at;
      while (space(at)) ++at;
      if (at < html.size() && (html[at] == '"' || html[at] == '\'')) {
        const size_t close = html.find(html[at], at + 1);
        if (close == std::string::npos) break;
        value = html.substr(at + 1, close - at - 1);
        at = close + 1;
      } else {
        size_t end = at;
        while (end < html.size() && !space(end) && html[end] != '>') ++end;
        value = html.substr(at, end - at);
        at = end;
      }
    }
    attributes.emplace_back(std::move(name), DecodeEntities(value));
  }
  return attributes;
}

// The icons a page at `url` declares in its <head>, and its manifest's URL.
void ReadPage(const std::string& html_in, const std::string& url, std::vector<Candidate>& icons, std::string& manifest) {
  const std::string lower = Lower(html_in);
  const std::string html = html_in.substr(0, std::min(lower.find("</head"), lower.find("<body")));
  std::string base = url;
  for (size_t at = lower.find('<'); at != std::string::npos && at < html.size(); at = lower.find('<', at + 1)) {
    const bool is_link = lower.compare(at, 5, "<link") == 0;
    const bool is_base = lower.compare(at, 5, "<base") == 0;
    if ((!is_link && !is_base) || at + 5 >= html.size() || std::isalnum(static_cast<unsigned char>(html[at + 5]))) {
      continue;
    }
    std::string rel, href, sizes, type;
    for (const auto& [name, value] : Attributes(html, at + 5)) {
      if (name == "rel") rel = value;
      else if (name == "href") href = value;
      else if (name == "sizes") sizes = value;
      else if (name == "type") type = value;
    }
    if (href.empty()) continue;
    if (is_base) {
      base = Resolve(url, href);
      continue;
    }
    const std::vector<std::string> rels = Words(rel);
    const auto has = [&](const char* word) { return std::find(rels.begin(), rels.end(), word) != rels.end(); };
    if (has("manifest")) {
      if (manifest.empty()) manifest = Resolve(base, href);
      continue;
    }
    const bool touch = has("apple-touch-icon") || has("apple-touch-icon-precomposed");
    if (!touch && !has("icon")) continue;  // e.g. "mask-icon": a one-colour outline.
    Candidate icon{.url = Resolve(base, href)};
    ReadSizes(sizes, icon);
    // Apple's touch icons are 180px unless they say otherwise.
    if (touch && !icon.size && !icon.scalable) icon.size = 180;
    if (LooksLikeSvg(href, type)) icon.scalable = true;
    if (IsWeb(icon.url)) icons.push_back(icon);
  }
}

// The icons a web app manifest at `url` lists (those meant to be shown as
// they are: not masks or monochrome).
void ReadManifest(const std::string& json, const std::string& url, std::vector<Candidate>& icons) {
  CefRefPtr<CefValue> value = CefParseJSON(json, JSON_PARSER_ALLOW_TRAILING_COMMAS);
  if (!value || value->GetType() != VTYPE_DICTIONARY) return;
  CefRefPtr<CefListValue> list = value->GetDictionary()->GetList("icons");
  for (size_t i = 0; list && i < list->GetSize(); ++i) {
    CefRefPtr<CefDictionaryValue> entry = list->GetDictionary(i);
    if (!entry) continue;
    const std::string purpose = entry->HasKey("purpose") ? entry->GetString("purpose").ToString() : "any";
    const std::vector<std::string> purposes = Words(purpose);
    if (std::find(purposes.begin(), purposes.end(), "any") == purposes.end()) continue;
    const std::string src = entry->GetString("src");
    Candidate icon{.url = Resolve(url, src)};
    ReadSizes(entry->GetString("sizes"), icon);
    if (LooksLikeSvg(src, entry->GetString("type"))) icon.scalable = true;
    if (IsWeb(icon.url)) icons.push_back(icon);
  }
}

// --- Fetching -----------------------------------------------------------------

struct Fetched {
  bool ok = false;  // A 2xx response (cut short past the size limit is fine).
  std::string url;  // After redirects.
  std::string mime;
  std::string body;
};

// One GET, its body capped at `max` bytes. Calls back on the thread that
// started it.
class Fetch : public CefURLRequestClient {
 public:
  using Done = std::function<void(const Fetched&)>;

  static CefRefPtr<CefURLRequest> Start(const std::string& url,
                                        size_t max,
                                        CefRefPtr<CefRequestContext> context,
                                        Done done) {
    CefRefPtr<CefRequest> request = CefRequest::Create();
    request->SetURL(url);
    request->SetMethod("GET");
    return CefURLRequest::Create(request, new Fetch(max, std::move(done)), context);
  }

  void OnRequestComplete(CefRefPtr<CefURLRequest> request) override {
    Fetched result;
    CefRefPtr<CefResponse> response = request->GetResponse();
    const int status = response ? response->GetStatus() : 0;
    const bool complete = request->GetRequestStatus() == UR_SUCCESS || truncated_;
    result.ok = complete && status >= 200 && status < 300;
    if (response) {
      result.url = response->GetURL();
      result.mime = response->GetMimeType();
    }
    result.body = std::move(body_);
    if (done_) std::exchange(done_, nullptr)(result);
  }
  void OnUploadProgress(CefRefPtr<CefURLRequest>, int64_t, int64_t) override {}
  void OnDownloadProgress(CefRefPtr<CefURLRequest>, int64_t, int64_t) override {}
  void OnDownloadData(CefRefPtr<CefURLRequest> request, const void* data, size_t length) override {
    if (truncated_) return;
    if (body_.size() + length > max_) {
      truncated_ = true;
      request->Cancel();
      return;
    }
    body_.append(static_cast<const char*>(data), length);
  }
  bool GetAuthCredentials(bool, const CefString&, int, const CefString&, const CefString&, CefRefPtr<CefAuthCallback>)
      override {
    return false;
  }

 private:
  Fetch(size_t max, Done done) : max_(max), done_(std::move(done)) {}

  const size_t max_;
  Done done_;
  std::string body_;
  bool truncated_ = false;

  IMPLEMENT_REFCOUNTING(Fetch);
};

// --- The cache --------------------------------------------------------------

// Icons found are kept in the profile (<profile>/Site Icons), one file per
// site: <SHA-256 of the site's URL>.<type>. One younger than kFresh is used
// as it is; an older one is looked up again (and kept if that fails).
namespace cache {

namespace fs = std::filesystem;

constexpr char kFolder[] = "Site Icons";
constexpr auto kFresh = std::chrono::hours(24 * 30);

// Image types by extension; anything else is stored as an .ico (the image
// decoder sniffs the real type).
constexpr std::pair<const char*, const char*> kTypes[] = {
    {"png", "image/png"},   {"svg", "image/svg+xml"}, {"jpg", "image/jpeg"}, {"gif", "image/gif"},
    {"webp", "image/webp"}, {"avif", "image/avif"},   {"bmp", "image/bmp"},  {"ico", "image/x-icon"},
};

std::string KeyFor(const std::string& site) {
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(site.data(), static_cast<CC_LONG>(site.size()), digest);
  std::string key;
  for (unsigned char byte : digest) {
    char hex[3];
    std::snprintf(hex, sizeof(hex), "%02x", byte);
    key += hex;
  }
  return key;
}

struct Entry {
  std::string icon;
  std::string mime;
  bool fresh = false;
};

// File thread.
Entry Read(const fs::path& folder, const std::string& site) {
  const std::string key = KeyFor(site);
  for (const auto& [extension, mime] : kTypes) {
    const fs::path path = folder / (key + "." + extension);
    std::error_code error;
    const auto modified = fs::last_write_time(path, error);
    if (error) continue;
    std::ifstream file(path, std::ios::binary);
    Entry entry;
    entry.icon.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
    if (entry.icon.empty()) continue;
    entry.mime = mime;
    entry.fresh = fs::file_time_type::clock::now() - modified < kFresh;
    return entry;
  }
  return {};
}

// File thread. Replaces the site's icon, whatever its type was.
void Write(const fs::path& folder, const std::string& site, const std::string& icon, const std::string& mime) {
  std::error_code error;
  fs::create_directories(folder, error);
  if (error) return;
  const std::string key = KeyFor(site);
  const char* extension = "ico";
  for (const auto& [ext, type] : kTypes) {
    if (mime == type) extension = ext;
  }
  for (const auto& [ext, type] : kTypes) fs::remove(folder / (key + "." + ext), error);
  // Written aside, then moved into place: never a half-written icon.
  const fs::path temporary = folder / (key + ".partial");
  {
    std::ofstream file(temporary, std::ios::binary | std::ios::trunc);
    file.write(icon.data(), static_cast<std::streamsize>(icon.size()));
    if (!file) return;
  }
  fs::rename(temporary, folder / (key + "." + extension), error);
}

}  // namespace cache

// --- The handler --------------------------------------------------------------

// Works on the UI thread; CEF reads the result on the IO thread once it's
// told the response is ready (callback_->Continue()).
class SiteIconHandler : public CefResourceHandler {
 public:
  SiteIconHandler(CefRefPtr<CefBrowser> browser, std::string site) : browser_(browser), site_(std::move(site)) {}

  bool Open(CefRefPtr<CefRequest> request, bool& handle_request, CefRefPtr<CefCallback> callback) override {
    handle_request = false;
    callback_ = callback;
    CefPostTask(TID_UI, base::BindOnce(&SiteIconHandler::Start, CefRefPtr<SiteIconHandler>(this)));
    return true;
  }

  void GetResponseHeaders(CefRefPtr<CefResponse> response, int64_t& response_length, CefString& redirect_url) override {
    if (icon_.empty()) {
      response->SetStatus(404);
      response->SetStatusText("Not Found");
      response->SetMimeType("text/plain");
      response_length = 0;
      return;
    }
    response->SetStatus(200);
    response->SetStatusText("OK");
    response->SetMimeType(mime_);
    response_length = static_cast<int64_t>(icon_.size());
  }

  bool Read(void* data_out, int bytes_to_read, int& bytes_read, CefRefPtr<CefResourceReadCallback> callback) override {
    const size_t n = std::min(static_cast<size_t>(bytes_to_read), icon_.size() - offset_);
    std::copy_n(icon_.data() + offset_, n, static_cast<char*>(data_out));
    offset_ += n;
    bytes_read = static_cast<int>(n);
    return n > 0;
  }

  void Cancel() override {
    CefPostTask(TID_UI, base::BindOnce(&SiteIconHandler::Stop, CefRefPtr<SiteIconHandler>(this)));
  }

 private:
  CefRefPtr<CefRequestContext> Context() { return browser_->GetHost()->GetRequestContext(); }

  // The cached icon if it's fresh, else a lookup.
  void Start() {
    if (stopped_) return;
    const std::string profile = Context()->GetCachePath();
    if (profile.empty()) {  // In memory only: nothing kept.
      FetchPage();
      return;
    }
    folder_ = cache::fs::path(profile) / cache::kFolder;
    CefPostTask(TID_FILE_USER_VISIBLE, base::BindOnce(
                                           [](CefRefPtr<SiteIconHandler> self) {
                                             cache::Entry entry = cache::Read(self->folder_, self->site_);
                                             CefPostTask(TID_UI, base::BindOnce(&SiteIconHandler::OnCacheRead, self,
                                                                                std::move(entry.icon), std::move(entry.mime),
                                                                                entry.fresh));
                                           },
                                           CefRefPtr<SiteIconHandler>(this)));
  }

  void OnCacheRead(std::string icon, std::string mime, bool fresh) {
    if (stopped_) return;
    icon_ = std::move(icon);
    mime_ = std::move(mime);
    if (fresh) {
      Finish();
      return;
    }
    // Stale (kept in icon_ in case the lookup fails) or none.
    FetchPage();
  }

  void FetchPage() {
    if (stopped_) return;
    current_ = Fetch::Start(site_, kMaxPage, Context(), [this, self = CefRefPtr<SiteIconHandler>(this)](const Fetched& page) {
      std::string manifest;
      const std::string url = page.url.empty() ? site_ : page.url;
      origin_ = OriginOf(url);
      if (page.ok && Lower(page.mime).find("html") != std::string::npos) ReadPage(page.body, url, icons_, manifest);
      if (manifest.empty() || !IsWeb(manifest)) {
        TryIcons();
        return;
      }
      current_ = Fetch::Start(manifest, kMaxManifest, Context(), [this, self, manifest](const Fetched& found) {
        if (found.ok) ReadManifest(found.body, found.url.empty() ? manifest : found.url, icons_);
        TryIcons();
      });
    });
  }

  // Ranks what the site declared, adds the usual places, and tries each.
  void TryIcons() {
    if (stopped_) return;
    std::stable_sort(icons_.begin(), icons_.end(), Better);
    if (!origin_.empty()) {
      icons_.push_back({.url = origin_ + "/apple-touch-icon.png", .size = 180});
      icons_.push_back({.url = origin_ + "/favicon.ico"});
    }
    std::set<std::string> seen;
    for (const Candidate& icon : icons_) {
      if (seen.insert(icon.url).second) to_try_.push_back(icon.url);
    }
    TryNext();
  }

  void TryNext() {
    if (stopped_) return;
    if (next_ >= to_try_.size()) {
      Finish();
      return;
    }
    const std::string url = to_try_[next_++];
    current_ = Fetch::Start(url, kMaxIcon, Context(), [this, self = CefRefPtr<SiteIconHandler>(this)](const Fetched& found) {
      // Anything but a page (servers label .ico files all sorts of ways;
      // the image decoder decides).
      const std::string mime = Lower(found.mime);
      if (!found.ok || found.body.empty() || mime.find("html") != std::string::npos || mime.find("json") != std::string::npos) {
        TryNext();
        return;
      }
      icon_ = found.body;
      mime_ = mime.rfind("image/", 0) == 0 ? mime : "image/x-icon";
      if (!folder_.empty()) {
        CefPostTask(TID_FILE_USER_VISIBLE, base::BindOnce(&cache::Write, folder_, site_, icon_, mime_));
      }
      Finish();
    });
  }

  void Finish() {
    current_ = nullptr;
    if (stopped_) return;
    stopped_ = true;
    callback_->Continue();
  }

  void Stop() {
    stopped_ = true;
    if (current_) current_->Cancel();
    current_ = nullptr;
  }

  CefRefPtr<CefBrowser> browser_;
  const std::string site_;
  CefRefPtr<CefCallback> callback_;

  // UI thread.
  bool stopped_ = false;
  CefRefPtr<CefURLRequest> current_;
  cache::fs::path folder_;  // Empty: nothing kept.
  std::string origin_;
  std::vector<Candidate> icons_;
  std::vector<std::string> to_try_;
  size_t next_ = 0;

  // Set before callback_->Continue(); read after.
  std::string icon_;
  std::string mime_;
  size_t offset_ = 0;

  IMPLEMENT_REFCOUNTING(SiteIconHandler);
};

}  // namespace

CefRefPtr<CefResourceHandler> CreateHandler(CefRefPtr<CefBrowser> browser, const std::string& site) {
  if (!browser || !IsWeb(site)) return nullptr;
  return new SiteIconHandler(browser, site);
}

}  // namespace site_icon
