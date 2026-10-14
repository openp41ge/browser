// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/github.h"

#include <regex>

#include "include/cef_command_line.h"
#include "include/cef_parser.h"
#include "include/cef_urlrequest.h"
#include "include/wrapper/cef_helpers.h"

namespace github {

namespace {

constexpr char kApi[] = "https://api.github.com";
constexpr size_t kMaxApiBytes = 4 * 1024 * 1024;

std::string ApiBase() {
  std::string base = CefCommandLine::GetGlobalCommandLine()->GetSwitchValue("github-api");
  if (base.empty()) base = kApi;
  while (!base.empty() && base.back() == '/') base.pop_back();
  return base;
}

// A GET, its body collected (up to a limit).
class Fetch : public CefURLRequestClient {
 public:
  using Done = std::function<void(int status, std::string body, std::string error)>;

  Fetch(size_t max_bytes, Done done) : max_bytes_(max_bytes), done_(std::move(done)) {}

  static void Start(const std::string& url, size_t max_bytes, Done done) {
    CEF_REQUIRE_UI_THREAD();
    CefRefPtr<CefRequest> request = CefRequest::Create();
    request->SetURL(url);
    request->SetMethod("GET");
    CefRequest::HeaderMap headers;
    headers.insert({"User-Agent", "openp41ge-explorer"});
    headers.insert({"Accept", "application/vnd.github+json"});
    request->SetHeaderMap(headers);
    // No cookies or stored credentials: an anonymous request.
    request->SetFlags(UR_FLAG_DISABLE_CACHE);
    CefURLRequest::Create(request, new Fetch(max_bytes, std::move(done)), nullptr);
  }

  void OnRequestComplete(CefRefPtr<CefURLRequest> request) override {
    if (!done_) return;
    CefRefPtr<CefResponse> response = request->GetResponse();
    const int status = response ? response->GetStatus() : 0;
    if (too_big_) {
      Finish(status, "", "it's larger than " + std::to_string(max_bytes_ / (1024 * 1024)) + " MB");
    } else if (request->GetRequestStatus() != UR_SUCCESS) {
      Finish(status, "", "couldn't reach " + request->GetRequest()->GetURL().ToString());
    } else {
      Finish(status, std::move(body_), "");
    }
  }
  void OnDownloadData(CefRefPtr<CefURLRequest> request, const void* data, size_t length) override {
    if (body_.size() + length > max_bytes_) {
      too_big_ = true;
      request->Cancel();
      return;
    }
    body_.append(static_cast<const char*>(data), length);
  }
  void OnUploadProgress(CefRefPtr<CefURLRequest>, int64_t, int64_t) override {}
  void OnDownloadProgress(CefRefPtr<CefURLRequest>, int64_t, int64_t) override {}
  bool GetAuthCredentials(bool, const CefString&, int, const CefString&, const CefString&,
                          CefRefPtr<CefAuthCallback>) override {
    return false;
  }

 private:
  void Finish(int status, std::string body, std::string error) {
    Done done = std::move(done_);
    done_ = nullptr;
    done(status, std::move(body), std::move(error));
  }

  const size_t max_bytes_;
  Done done_;
  std::string body_;
  bool too_big_ = false;

  IMPLEMENT_REFCOUNTING(Fetch);
};

}  // namespace

std::string ParseRepo(const std::string& text) {
  static const std::regex repo(
      R"(^\s*(?:(?:https?://)?(?:www\.)?github\.com/)?([A-Za-z0-9-]+)/([A-Za-z0-9._-]+?)(?:\.git)?/?\s*$)");
  std::smatch match;
  if (!std::regex_match(text, match, repo)) return std::string();
  return match[1].str() + "/" + match[2].str();
}

void ListExtensions(const std::string& repo,
                    std::function<void(std::vector<Release> releases, std::string error)> done) {
  Fetch::Start(ApiBase() + "/repos/" + repo + "/releases?per_page=100", kMaxApiBytes,
               [repo, done](int status, std::string body, std::string error) {
    if (!error.empty()) return done({}, error);
    if (status == 404) return done({}, "there's no public repo " + repo + " on GitHub");
    if (status == 403 || status == 429) return done({}, "GitHub's limit on requests was reached: try again later");
    if (status != 200) return done({}, "GitHub answered " + std::to_string(status));
    CefRefPtr<CefValue> parsed = CefParseJSON(body, JSON_PARSER_RFC);
    CefRefPtr<CefListValue> list = parsed && parsed->GetType() == VTYPE_LIST ? parsed->GetList() : nullptr;
    if (!list) return done({}, "GitHub's answer wasn't a list of releases");
    // <id>-<version>.openp41ge-extension.zip; newest release first, so the
    // first of each id is its newest.
    static const std::regex asset_name(R"(^([a-z0-9][a-z0-9-]*?)-([0-9][^/]*)\.openp41ge-extension\.zip$)");
    std::vector<Release> releases;
    for (size_t i = 0; i < list->GetSize(); ++i) {
      CefRefPtr<CefDictionaryValue> release = list->GetDictionary(i);
      if (!release || release->GetBool("draft") || release->GetBool("prerelease")) continue;
      CefRefPtr<CefListValue> assets = release->GetList("assets");
      for (size_t j = 0; assets && j < assets->GetSize(); ++j) {
        CefRefPtr<CefDictionaryValue> asset = assets->GetDictionary(j);
        if (!asset) continue;
        const std::string name = asset->GetString("name");
        std::smatch match;
        if (!std::regex_match(name, match, asset_name)) continue;
        bool seen = false;
        for (const Release& r : releases) seen |= r.id == match[1].str();
        if (seen) continue;
        releases.push_back({match[1].str(), match[2].str(), release->GetString("tag_name"), name,
                            asset->GetString("browser_download_url")});
      }
    }
    if (releases.empty()) return done({}, repo + " has no releases with an openp41ge extension");
    done(std::move(releases), "");
  });
}

bool IsNewer(const std::string& a, const std::string& b) {
  auto parts = [](const std::string& version) {
    std::vector<long> numbers;
    size_t at = 0;
    while (at < version.size()) {
      size_t end = at;
      while (end < version.size() && isdigit(static_cast<unsigned char>(version[end]))) ++end;
      numbers.push_back(end > at ? std::stol(version.substr(at, end - at)) : 0);
      at = version.find('.', end);
      if (at == std::string::npos) break;
      ++at;
    }
    return numbers;
  };
  std::vector<long> x = parts(a), y = parts(b);
  const size_t n = std::max(x.size(), y.size());
  x.resize(n, 0);
  y.resize(n, 0);
  return x > y;
}

void Download(const std::string& url, size_t max_bytes, std::function<void(std::string body, std::string error)> done) {
  Fetch::Start(url, max_bytes, [done](int status, std::string body, std::string error) {
    if (!error.empty()) return done("", error);
    if (status != 200) return done("", "the download answered " + std::to_string(status));
    done(std::move(body), "");
  });
}

}  // namespace github
