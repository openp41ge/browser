// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/extension.h"

#include <filesystem>
#include <fstream>
#include <iterator>
#include <regex>
#include <set>

#include "include/cef_parser.h"

namespace extensions {

namespace {

namespace fs = std::filesystem;

// Reads a manifest's parts. Each check that fails records what's wrong (the
// first problem only) and returns false or nothing.
class Reader {
 public:
  explicit Reader(fs::path folder) : folder_(std::move(folder)) {}

  const std::string& error() const { return error_; }

  bool Fail(const std::string& message) {
    if (error_.empty()) error_ = message;
    return false;
  }

  // Keys an object may have: any other is a mistake (a misspelt key would
  // otherwise be ignored without a word).
  bool CheckKeys(CefRefPtr<CefDictionaryValue> object, const std::set<std::string>& allowed, const std::string& where) {
    CefDictionaryValue::KeyList keys;
    object->GetKeys(keys);
    for (const CefString& key : keys) {
      if (!allowed.count(key.ToString())) return Fail(where + ": unknown key \"" + key.ToString() + "\"");
    }
    return true;
  }

  bool String(CefRefPtr<CefDictionaryValue> object, const std::string& key, const std::string& where, bool required,
              std::string* out) {
    if (!object->HasKey(key)) return !required || Fail(where + ": \"" + key + "\" is missing");
    if (object->GetType(key) != VTYPE_STRING) return Fail(where + ": \"" + key + "\" must be a string");
    *out = object->GetString(key).ToString();
    return true;
  }

  // A list of strings; `required`: at least one.
  bool Strings(CefRefPtr<CefDictionaryValue> object, const std::string& key, const std::string& where, bool required,
               std::vector<std::string>* out) {
    if (!object->HasKey(key)) return !required || Fail(where + ": \"" + key + "\" is missing");
    const std::string wrong = where + ": \"" + key + "\" must be a list of strings";
    if (object->GetType(key) != VTYPE_LIST) return Fail(wrong);
    CefRefPtr<CefListValue> list = object->GetList(key);
    for (size_t i = 0; i < list->GetSize(); ++i) {
      if (list->GetType(i) != VTYPE_STRING) return Fail(wrong);
      out->push_back(list->GetString(i).ToString());
    }
    return !(required && out->empty()) || Fail(where + ": \"" + key + "\" is empty");
  }

  // The objects in a list.
  bool Objects(CefRefPtr<CefDictionaryValue> object, const std::string& key, const std::string& where,
               std::vector<CefRefPtr<CefDictionaryValue>>* out) {
    if (!object->HasKey(key)) return true;
    if (object->GetType(key) != VTYPE_LIST) return Fail(where + ": \"" + key + "\" must be a list");
    CefRefPtr<CefListValue> list = object->GetList(key);
    for (size_t i = 0; i < list->GetSize(); ++i) {
      if (list->GetType(i) != VTYPE_DICTIONARY) {
        return Fail(where + ": " + key + "[" + std::to_string(i) + "] must be an object");
      }
      out->push_back(list->GetDictionary(i));
    }
    return true;
  }

  // A file the manifest names: relative, inside the folder (also once links
  // are followed), and readable.
  bool File(const std::string& path, const std::string& where, Extension::File* out) {
    const fs::path relative(path);
    bool climbs = false;
    for (const fs::path& part : relative) climbs |= part == "..";
    if (path.empty() || relative.is_absolute() || climbs || path.find('\\') != std::string::npos) {
      return Fail(where + ": \"" + path + "\" must be a path inside the extension's folder");
    }
    std::error_code error;
    const fs::path file = fs::canonical(folder_ / relative, error);
    if (error || file.string().rfind((folder_ / "").string(), 0) != 0 || !fs::is_regular_file(file)) {
      return Fail(where + ": no file \"" + path + "\" in the extension's folder");
    }
    std::ifstream stream(file, std::ios::binary);
    if (!stream) return Fail(where + ": couldn't read \"" + path + "\"");
    out->path = path;
    out->text.assign(std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>());
    return true;
  }

  bool Files(CefRefPtr<CefDictionaryValue> object, const std::string& key, const std::string& where,
             std::vector<Extension::File>* out) {
    std::vector<std::string> paths;
    if (!Strings(object, key, where, false, &paths)) return false;
    for (const std::string& path : paths) {
      out->emplace_back();
      if (!File(path, where, &out->back())) return false;
    }
    return true;
  }

 private:
  const fs::path folder_;
  std::string error_;
};

bool ReadFeature(Reader& reader, CefRefPtr<CefDictionaryValue> item, const std::string& at, Extension::Feature* out) {
  if (!reader.CheckKeys(item, {"id", "name", "enabledByDefault"}, at) || !reader.String(item, "id", at, true, &out->id) ||
      !reader.String(item, "name", at, true, &out->name)) {
    return false;
  }
  if (item->HasKey("enabledByDefault")) {
    if (item->GetType("enabledByDefault") != VTYPE_BOOL) return reader.Fail(at + ": \"enabledByDefault\" must be true or false");
    out->enabled_by_default = item->GetBool("enabledByDefault");
  }
  return true;
}

bool ReadPage(Reader& reader, CefRefPtr<CefDictionaryValue> item, const std::string& at, Extension::Page* out) {
  std::string role;
  Extension::File file;
  if (!reader.CheckKeys(item, {"path", "title", "role"}, at) || !reader.String(item, "path", at, true, &out->path) ||
      !reader.String(item, "title", at, true, &out->title) || !reader.String(item, "role", at, false, &role) ||
      !reader.File(out->path, at, &file)) {
    return false;
  }
  if (!role.empty() && role != "settings") return reader.Fail(at + ": \"role\" must be \"settings\"");
  out->settings = role == "settings";
  return true;
}

bool ReadContentScript(Reader& reader,
                       CefRefPtr<CefDictionaryValue> item,
                       const std::string& at,
                       const std::vector<Extension::Feature>& features,
                       Extension::ContentScript* out) {
  if (!reader.CheckKeys(item, {"matches", "js", "css", "runAt", "feature"}, at) ||
      !reader.Strings(item, "matches", at, true, &out->matches)) {
    return false;
  }
  for (const std::string& pattern : out->matches) {
    if (!IsMatchPattern(pattern)) return reader.Fail(at + ": \"" + pattern + "\" isn't a match pattern");
  }
  if (!reader.Files(item, "js", at, &out->js) || !reader.Files(item, "css", at, &out->css)) return false;
  if (out->js.empty() && out->css.empty()) return reader.Fail(at + ": has no \"js\" or \"css\"");
  std::string run_at;
  if (!reader.String(item, "runAt", at, false, &run_at)) return false;
  if (!run_at.empty() && run_at != "document_start" && run_at != "document_idle") {
    return reader.Fail(at + ": \"runAt\" must be \"document_start\" or \"document_idle\"");
  }
  out->run_at_start = run_at == "document_start";
  if (!reader.String(item, "feature", at, false, &out->feature)) return false;
  if (out->feature.empty()) return true;
  for (const Extension::Feature& feature : features) {
    if (feature.id == out->feature) return true;
  }
  return reader.Fail(at + ": no feature \"" + out->feature + "\" in \"features\"");
}

}  // namespace

bool IsMatchPattern(const std::string& pattern) {
  // <all_urls>, or scheme://host[:port]/path: scheme * (http and https),
  // http or https; host *, *.domain or a host name; any path, * a wildcard.
  static const std::regex syntax(R"(^(<all_urls>|(\*|https?)://(\*|(\*\.)?[^/*:]+)(:(\*|[0-9]+))?/.*)$)");
  return std::regex_match(pattern, syntax);
}

std::optional<Extension> Load(const std::string& folder_path, std::string* error) {
  auto failed = [error](const std::string& message) -> std::optional<Extension> {
    if (error) *error = message;
    return std::nullopt;
  };
  std::error_code fs_error;
  const fs::path folder = fs::canonical(folder_path, fs_error);
  if (fs_error || !fs::is_directory(folder)) return failed("no folder at " + folder_path);

  Reader reader(folder);
  Extension::File manifest_file;
  if (!reader.File(kManifestFile, folder_path, &manifest_file)) return failed(reader.error());
  const std::string where = kManifestFile;
  CefString json_error;
  CefRefPtr<CefValue> parsed = CefParseJSONAndReturnError(manifest_file.text, JSON_PARSER_RFC, json_error);
  CefRefPtr<CefDictionaryValue> manifest = parsed ? parsed->GetDictionary() : nullptr;
  if (!manifest) return failed(where + ": not a JSON object (" + json_error.ToString() + ")");

  Extension extension;
  extension.folder = folder.string();
  bool ok = reader.CheckKeys(manifest,
                             {"manifestVersion", "id", "name", "version", "description", "contentScripts", "features",
                              "config", "pages"},
                             where);
  ok = ok && ((manifest->GetType("manifestVersion") == VTYPE_INT && manifest->GetInt("manifestVersion") == 1) ||
              reader.Fail(where + ": \"manifestVersion\" must be 1"));
  ok = ok && reader.String(manifest, "id", where, true, &extension.id);
  static const std::regex id_syntax("^[a-z0-9][a-z0-9-]{0,63}$");
  ok = ok && (std::regex_match(extension.id, id_syntax) ||
              reader.Fail(where + ": \"id\" must be lowercase letters, digits and dashes (\"" + extension.id + "\")"));
  ok = ok && reader.String(manifest, "name", where, true, &extension.name);
  ok = ok && (!extension.name.empty() || reader.Fail(where + ": \"name\" is empty"));
  ok = ok && reader.String(manifest, "version", where, true, &extension.version);
  ok = ok && reader.String(manifest, "description", where, false, &extension.description);

  std::vector<CefRefPtr<CefDictionaryValue>> items;
  ok = ok && reader.Objects(manifest, "features", where, &items);
  for (size_t i = 0; ok && i < items.size(); ++i) {
    const std::string at = where + ": features[" + std::to_string(i) + "]";
    Extension::Feature feature;
    ok = ReadFeature(reader, items[i], at, &feature);
    for (const Extension::Feature& other : extension.features) {
      ok = ok && (other.id != feature.id || reader.Fail(at + ": another feature has the id \"" + feature.id + "\""));
    }
    extension.features.push_back(feature);
  }

  items.clear();
  ok = ok && reader.Objects(manifest, "contentScripts", where, &items);
  for (size_t i = 0; ok && i < items.size(); ++i) {
    extension.content_scripts.emplace_back();
    ok = ReadContentScript(reader, items[i], where + ": contentScripts[" + std::to_string(i) + "]", extension.features,
                           &extension.content_scripts.back());
  }

  items.clear();
  ok = ok && reader.Objects(manifest, "pages", where, &items);
  for (size_t i = 0; ok && i < items.size(); ++i) {
    const std::string at = where + ": pages[" + std::to_string(i) + "]";
    Extension::Page page;
    ok = ReadPage(reader, items[i], at, &page);
    for (const Extension::Page& other : extension.pages) {
      ok = ok && (other.path != page.path || reader.Fail(at + ": another page has the path \"" + page.path + "\""));
      ok = ok && (!(other.settings && page.settings) || reader.Fail(at + ": another page is the settings page"));
    }
    extension.pages.push_back(page);
  }

  // The schema itself is checked in the page, by the code editor's config
  // logic (the runtime): here, only that there's one.
  if (ok && manifest->HasKey("config")) {
    if (manifest->GetType("config") != VTYPE_DICTIONARY) {
      ok = reader.Fail(where + ": \"config\" must be an object (a JSON Schema)");
    } else {
      extension.config_schema = CefWriteJSON(manifest->GetValue("config"), JSON_WRITER_DEFAULT).ToString();
    }
  }

  if (!ok) return failed(reader.error());
  return extension;
}

}  // namespace extensions
