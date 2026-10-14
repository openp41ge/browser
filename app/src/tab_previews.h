// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_TAB_PREVIEWS_H_
#define OPENP41GE_EXPLORER_TAB_PREVIEWS_H_

#include <set>
#include <string>

// Pictures of tabs' pages (JPEG), shown under a tab while the pointer rests
// on it (tab_preview.h): taken while a tab shows, since a hidden page isn't
// drawn. Each has a token (Tab::preview). Kept in memory, and
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

// `image` (a page's screenshot, any format) scaled by `factor` (at most 1),
// as JPEG at `quality` (0 to 100); empty if it can't be read.
//
// Screenshots are taken at full size and shrunk here, not with
// Page.captureScreenshot's clip scale: Chromium does that by emulating a
// smaller viewport scale on the page for the capture and undoing it after,
// and when the undo is lost (as a page goes to another process mid-capture)
// the page stays drawn shrunk in the corner of its view.
std::string Shrink(const std::string& image, double factor, int quality);

}  // namespace tab_previews

#endif  // OPENP41GE_EXPLORER_TAB_PREVIEWS_H_
