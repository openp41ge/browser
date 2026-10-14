// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_H_

#include <optional>
#include <string>
#include <vector>

// An extension: a folder with a manifest (openp41ge-extension.json) and
// plain JavaScript and CSS. See plans/2026-10-14-extension-system.md.
struct Extension {
  struct File {
    std::string path;  // As the manifest names it, relative to the folder.
    std::string text;
  };
  struct ContentScript {
    // Chrome's match-pattern syntax ("*://*.youtube.com/*", "<all_urls>");
    // checked here, matched by the runtime in the page.
    std::vector<std::string> matches;
    std::vector<File> js;
    std::vector<File> css;
    bool run_at_start = false;  // "document_start"; else "document_idle".
    std::string feature;        // Runs only while this feature is on.
  };
  struct Feature {
    std::string id;
    std::string name;
    bool enabled_by_default = true;
  };
  // A page of its own, opened as a tab (extension_scheme.h).
  struct Page {
    std::string path;   // In the folder.
    std::string title;  // What the Extensions page calls it.
    bool settings = false;  // "role": "settings": the extension's settings.
  };

  std::string folder;
  std::string id;
  std::string name;
  std::string version;
  std::string description;
  std::vector<ContentScript> content_scripts;
  std::vector<Feature> features;
  std::vector<Page> pages;
  // The manifest's "config": its settings' JSON Schema, with their defaults
  // (as JSON; empty if it has none). Checked and used by the runtime in the
  // page, with the code editor's config logic.
  std::string config_schema;
};

namespace extensions {

constexpr char kManifestFile[] = "openp41ge-extension.json";

// Reads the extension in `folder`: its manifest, checked, and the files its
// content scripts name. On a problem, nothing, and `error` says what.
std::optional<Extension> Load(const std::string& folder, std::string* error);

// Whether `pattern` is a match pattern the runtime understands.
bool IsMatchPattern(const std::string& pattern);

}  // namespace extensions

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_H_
