// Copyright (c) 2026 Richard Kielty. MIT License.

#include "history.h"

#include <algorithm>
#include <cctype>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <set>
#include <sstream>
#include <utility>

#include "include/base/cef_callback.h"
#include "include/cef_parser.h"
#include "include/cef_task.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

namespace {

constexpr char kFile[] = "Address History.json";
// Written this long after a change (changes in between go with it).
constexpr int64_t kSaveDelayMs = 2000;
// Kept: the most recently visited.
constexpr size_t kMaxEntries = 10000;

int64_t Now() {
  return static_cast<int64_t>(std::time(nullptr));
}

std::string Lower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
  return s;
}

bool StartsWith(const std::string& s, const std::string& prefix) {
  return s.rfind(prefix, 0) == 0;
}

std::string StripPrefix(std::string s, const char* prefix) {
  return StartsWith(Lower(s), prefix) ? s.substr(std::char_traits<char>::length(prefix)) : s;
}

bool IsWeb(const std::string& url) {
  return StartsWith(url, "http://") || StartsWith(url, "https://");
}

// An address as shown and completed: no scheme, "www." or lone "/".
std::string TextOf(const std::string& url) {
  std::string text = StripPrefix(StripPrefix(url, "https://"), "http://");
  text = StripPrefix(text, "www.");
  const size_t slash = text.find('/');
  if (slash != std::string::npos && slash + 1 == text.size()) text.pop_back();
  return text;
}

// "https://www.example.com/a" -> "https://www.example.com/".
std::string RootOf(const std::string& url) {
  const size_t scheme = url.find("://");
  if (scheme == std::string::npos) return url;
  const size_t slash = url.find('/', scheme + 3);
  return slash == std::string::npos ? url + "/" : url.substr(0, slash + 1);
}

std::vector<std::string> Terms(const std::string& s) {
  std::istringstream in(s);
  return {std::istream_iterator<std::string>(in), std::istream_iterator<std::string>()};
}

// Every term starts a word of `haystack` (words split at anything not a
// letter or digit), e.g. "tube" doesn't match "youtube" but "watch" matches
// "youtube.com/watch".
bool WordsMatch(const std::vector<std::string>& terms, const std::string& haystack) {
  for (const std::string& term : terms) {
    bool found = false;
    for (size_t at = haystack.find(term); at != std::string::npos; at = haystack.find(term, at + 1)) {
      if (at == 0 || !std::isalnum(static_cast<unsigned char>(haystack[at - 1]))) {
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}

void WriteFile(const std::string& path, const std::string& contents) {
  namespace fs = std::filesystem;
  std::error_code error;
  fs::create_directories(fs::path(path).parent_path(), error);
  const std::string temporary = path + ".partial";
  {
    std::ofstream file(temporary, std::ios::binary | std::ios::trunc);
    file << contents;
    if (!file) return;
  }
  fs::rename(temporary, path, error);
}

}  // namespace

History::History(std::string folder) : path_(folder.empty() ? std::string() : folder + "/" + kFile) {
  Load();
}

History::~History() = default;

void History::AddVisit(const std::string& url) {
  if (!IsWeb(url)) return;
  Entry& entry = entries_[url];
  entry.visits++;
  entry.last_visit = Now();
  Changed();
}

void History::SetTitle(const std::string& url, const std::string& title) {
  auto it = entries_.find(url);
  if (it == entries_.end() || it->second.title == title) return;
  it->second.title = title;
  Changed();
}

void History::AddTyped(const std::string& url) {
  if (!IsWeb(url)) return;
  entries_[url].typed++;
  Changed();
}

std::vector<History::Match> History::Find(const std::string& typed, size_t max) const {
  std::string query = Lower(typed);
  query.erase(0, query.find_first_not_of(' '));
  query.erase(query.find_last_not_of(' ') + 1);
  query = StripPrefix(StripPrefix(StripPrefix(query, "https://"), "http://"), "www.");
  if (query.empty() || entries_.empty()) return {};
  const std::vector<std::string> terms = Terms(query);

  // Pages, and the sites they're on (a site counts all its pages' visits).
  struct Candidate {
    std::string url;
    std::string title;
    int visits = 0;
    int typed = 0;
    int64_t last_visit = 0;
  };
  std::map<std::string, Candidate> candidates;  // By lower-case text.
  for (const auto& [url, entry] : entries_) {
    Candidate& page = candidates[Lower(TextOf(url))];
    page.url = url;
    page.title = entry.title.empty() ? page.title : entry.title;
    page.visits += entry.visits;
    page.typed += entry.typed;
    page.last_visit = std::max(page.last_visit, entry.last_visit);

    const std::string root = RootOf(url);
    if (root == url) continue;
    Candidate& site = candidates[Lower(TextOf(root))];
    // The site's address: its home page if that was visited, else the
    // scheme and host its pages used.
    if (site.url.empty()) site.url = root;
    site.visits += entry.visits;
    site.typed += entry.typed;
    site.last_visit = std::max(site.last_visit, entry.last_visit);
  }

  struct Scored {
    Match match;
    bool prefix;
    double score;
  };
  const int64_t now = Now();
  std::vector<Scored> found;
  for (const auto& [text, candidate] : candidates) {
    if (candidate.visits == 0 && candidate.typed == 0) continue;
    const bool prefix = StartsWith(text, query);
    if (!prefix && !WordsMatch(terms, text + " " + Lower(candidate.title))) continue;
    const int64_t age = now - candidate.last_visit;
    const double recency = age < 2 * 86400 ? 10 : age < 30 * 86400 ? 4 : 0;
    const double score = candidate.typed * 20.0 + candidate.visits + recency;
    found.push_back({{candidate.url, candidate.title, TextOf(candidate.url), prefix}, prefix, score});
  }
  // Addresses that start with what was typed first (they can complete it),
  // then the rest; each by how often and lately they were used, shorter
  // addresses first on a tie (the site before its pages).
  std::sort(found.begin(), found.end(), [](const Scored& a, const Scored& b) {
    if (a.prefix != b.prefix) return a.prefix;
    if (a.score != b.score) return a.score > b.score;
    return a.match.text.size() < b.match.text.size();
  });
  std::vector<Match> matches;
  for (size_t i = 0; i < found.size() && matches.size() < max; ++i) matches.push_back(found[i].match);
  return matches;
}

void History::Remove(const std::string& text) {
  const std::string key = Lower(text);
  bool removed = false;
  for (auto it = entries_.begin(); it != entries_.end();) {
    // The keys Find() groups entries under: the page's, and its site's.
    if (Lower(TextOf(it->first)) == key || Lower(TextOf(RootOf(it->first))) == key) {
      it = entries_.erase(it);
      removed = true;
    } else {
      ++it;
    }
  }
  if (!removed) return;
  dirty_ = true;
  Flush();
}

void History::Flush() {
  if (!dirty_ || !loaded_ || path_.empty()) return;
  dirty_ = false;
  CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&WriteFile, path_, Serialize()));
}

void History::SaveNow() {
  if (!dirty_ || !loaded_ || path_.empty()) return;
  dirty_ = false;
  WriteFile(path_, Serialize());
}

void History::Changed() {
  if (entries_.size() > kMaxEntries) {
    // The least recently visited go.
    std::vector<std::pair<int64_t, std::string>> by_age;
    for (const auto& [url, entry] : entries_) by_age.emplace_back(entry.last_visit, url);
    std::sort(by_age.begin(), by_age.end());
    for (size_t i = 0; i < entries_.size() - kMaxEntries; ++i) entries_.erase(by_age[i].second);
  }
  dirty_ = true;
  if (save_pending_ || path_.empty()) return;
  save_pending_ = true;
  CefPostDelayedTask(TID_UI,
                     base::BindOnce(
                         [](History* self) {
                           self->save_pending_ = false;
                           self->Flush();
                         },
                         base::Unretained(this)),
                     kSaveDelayMs);
}

void History::Load() {
  if (path_.empty()) return;
  CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(
                                          [](History* self, std::string path) {
                                            std::ifstream file(path, std::ios::binary);
                                            std::string json((std::istreambuf_iterator<char>(file)),
                                                             std::istreambuf_iterator<char>());
                                            CefPostTask(TID_UI, base::BindOnce(&History::OnLoaded,
                                                                               base::Unretained(self), std::move(json)));
                                          },
                                          base::Unretained(this), path_));
}

void History::OnLoaded(const std::string& json) {
  loaded_ = true;
  CefRefPtr<CefValue> value = CefParseJSON(json, JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> root = value ? value->GetDictionary() : nullptr;
  CefRefPtr<CefListValue> list = root ? root->GetList("entries") : nullptr;
  for (size_t i = 0; list && i < list->GetSize(); ++i) {
    CefRefPtr<CefDictionaryValue> item = list->GetDictionary(i);
    if (!item) continue;
    const std::string url = item->GetString("url");
    if (!IsWeb(url)) continue;
    // Added to anything recorded since startup.
    Entry& entry = entries_[url];
    if (entry.title.empty()) entry.title = item->GetString("title");
    entry.visits += item->GetInt("visits");
    entry.typed += item->GetInt("typed");
    entry.last_visit = std::max(entry.last_visit, static_cast<int64_t>(item->GetDouble("last")));
  }
  if (dirty_) Flush();
}

std::string History::Serialize() const {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const auto& [url, entry] : entries_) {
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetString("url", url);
    item->SetString("title", entry.title);
    item->SetInt("visits", entry.visits);
    item->SetInt("typed", entry.typed);
    item->SetDouble("last", static_cast<double>(entry.last_visit));
    list->SetDictionary(list->GetSize(), item);
  }
  CefRefPtr<CefDictionaryValue> root = CefDictionaryValue::Create();
  root->SetInt("version", 1);
  root->SetList("entries", list);
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(root);
  return CefWriteJSON(value, JSON_WRITER_DEFAULT);
}
