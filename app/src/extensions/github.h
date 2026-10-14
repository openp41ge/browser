// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_GITHUB_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_GITHUB_H_

#include <functional>
#include <string>
#include <vector>

// Extensions from GitHub releases: a repo's releases list its extensions'
// zips (assets named <id>-<version>.openp41ge-extension.zip, as
// browser-community's release workflow publishes them, one release per
// extension and version), and the browser downloads one. It never builds a
// repo. See plans/2026-10-14-extension-system.md, "Installing from GitHub".
//
// The API is https://api.github.com, or --github-api=<url> (the tests' local
// stand-in). Unauthenticated: 60 requests an hour per IP. UI thread.
namespace github {

// The newest release of one extension in a repo.
struct Release {
  std::string id;         // From the asset's name.
  std::string version;
  std::string tag;
  std::string asset;      // Its name.
  std::string asset_url;  // Where to download it.
};

// "owner/repo" from what the user typed: owner/repo, or a github.com URL.
// Empty if it isn't one.
std::string ParseRepo(const std::string& text);

// The newest release of each extension in `repo` (newest first; not drafts
// or pre-releases); or an error.
void ListExtensions(const std::string& repo,
                    std::function<void(std::vector<Release> releases, std::string error)> done);

// Whether version `a` is newer than `b`: their dot-separated numbers
// compared in turn ("1.10.0" > "1.9.2"; a missing part is 0; anything after
// a part's digits, such as "-beta", is ignored).
bool IsNewer(const std::string& a, const std::string& b);

// Downloads `url` (at most `max_bytes`); or an error.
void Download(const std::string& url,
              size_t max_bytes,
              std::function<void(std::string body, std::string error)> done);

}  // namespace github

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_GITHUB_H_
