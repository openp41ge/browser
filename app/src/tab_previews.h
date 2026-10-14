// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_PREVIEWS_H_
#define OPENP41GE_EXPLORER_TAB_PREVIEWS_H_

#include <set>
#include <string>

// Pictures of tabs' pages (JPEG), for the tab bar to show (its previews):
// taken while a tab shows, since a hidden page isn't drawn. Each has a token
// (Tab::preview) and is served to the browser's UI at
// openp41ge://ui/preview/<token>.jpg (not to web pages). Kept in memory, and
// in the profile (<profile>/Tab Previews/<token>.jpg) for the session to
// bring back; not a private window's. Get is for any thread; the rest are
// for the UI thread.
namespace tab_previews {

// The folder in the profile they're kept in (empty: memory only).
void Init(const std::string& profile_folder);
// A new token, for a tab's first picture.
std::string NewToken();
// A tab's picture, kept in memory; and in the profile if `keep`.
void Put(const std::string& token, std::string jpeg, bool keep);
// A picture kept in the profile, read into memory (a tab brought back).
// False if there's none.
bool Load(const std::string& token);
// The picture for `token`, or empty.
std::string Get(const std::string& token);
// Its tab has gone: out of memory (the profile's copy goes with KeepOnly).
void Forget(const std::string& token);
// Deletes the pictures in the profile but these (the session's tabs').
void KeepOnly(std::set<std::string> tokens);
// Whether `token` could be one (what the scheme serves).
bool IsToken(const std::string& token);

}  // namespace tab_previews

#endif  // OPENP41GE_EXPLORER_TAB_PREVIEWS_H_
