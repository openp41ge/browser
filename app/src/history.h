// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_HISTORY_H_
#define OPENP41GE_EXPLORER_HISTORY_H_

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include "include/cef_base.h"

// The pages the browser has been to, for completing what's typed in a tab's
// address (the tab bar's suggestions). Kept in the profile as JSON
// (<profile>/Address History.json), read at startup and written a moment
// after it changes. UI thread.
class History {
 public:
  struct Match {
    std::string url;
    std::string title;
    // The address as shown and completed: no scheme, "www." or trailing
    // slash, e.g. "youtube.com" or "youtube.com/watch?v=…".
    std::string text;
    // `text` starts with what was typed: it can complete it inline.
    bool completes = false;
  };

  // `folder`: the profile's folder (empty: kept in memory only).
  explicit History(std::string folder);
  ~History();

  // A page shown in a tab (http and https only).
  void AddVisit(const std::string& url);
  void SetTitle(const std::string& url, const std::string& title);
  // An address typed in a tab: it counts for more than one only visited.
  void AddTyped(const std::string& url);

  // The best matches for `typed`, best first: whole sites as well as pages.
  std::vector<Match> Find(const std::string& typed, size_t max) const;
  // Forgets what made the match whose text is `text`: that page, and if it's
  // a site, every page on it. Written straight away.
  void Remove(const std::string& text);

  // Writes any change soon (on the file thread).
  void Flush();
  // Writes any change before returning: as the app quits, when work posted
  // elsewhere may not run.
  void SaveNow();

 private:
  struct Entry {
    std::string title;
    int visits = 0;
    int typed = 0;
    int64_t last_visit = 0;  // Seconds since the epoch.
  };

  void Changed();
  void Load();
  void OnLoaded(const std::string& json);
  std::string Serialize() const;

  std::string path_;
  std::map<std::string, Entry> entries_;  // By URL.
  // Nothing is written until the file has been read (it would lose what's
  // in it).
  bool loaded_ = false;
  bool save_pending_ = false;
  bool dirty_ = false;
};

#endif  // OPENP41GE_EXPLORER_HISTORY_H_
