// Copyright (c) 2026 Richard Kielty. MIT License.

#include "session.h"

#include <filesystem>
#include <fstream>
#include <iterator>

#include "include/base/cef_callback.h"
#include "include/cef_parser.h"
#include "include/cef_task.h"
#include "include/wrapper/cef_closure_task.h"

namespace session {

namespace {

constexpr char kFile[] = "Session.json";

std::string PathIn(const std::string& folder) {
  return folder + "/" + kFile;
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

std::string Serialize(const std::vector<WindowLayout>& windows) {
  CefRefPtr<CefListValue> list = CefListValue::Create();
  for (const WindowLayout& layout : windows) {
    CefRefPtr<CefListValue> panes = CefListValue::Create();
    for (const WindowLayout::PaneTabs& pane : layout.panes) {
      CefRefPtr<CefListValue> tabs = CefListValue::Create();
      for (const WindowLayout::SavedTab& tab : pane.tabs) {
        CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
        item->SetString("url", tab.url);
        item->SetString("title", tab.title);
        item->SetString("favicon", tab.favicon);
        item->SetString("preview", tab.preview);
        tabs->SetDictionary(tabs->GetSize(), item);
      }
      CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
      item->SetList("tabs", tabs);
      item->SetInt("active", pane.active);
      item->SetInt("weight", pane.weight);
      panes->SetDictionary(panes->GetSize(), item);
    }
    CefRefPtr<CefListValue> bounds = CefListValue::Create();
    for (int value : {layout.bounds.x, layout.bounds.y, layout.bounds.width, layout.bounds.height}) {
      bounds->SetInt(bounds->GetSize(), value);
    }
    CefRefPtr<CefDictionaryValue> item = CefDictionaryValue::Create();
    item->SetList("bounds", bounds);
    item->SetList("panes", panes);
    item->SetInt("active_pane", layout.active_pane);
    item->SetBool("previews", layout.previews);
    list->SetDictionary(list->GetSize(), item);
  }
  CefRefPtr<CefDictionaryValue> root = CefDictionaryValue::Create();
  root->SetInt("version", 1);
  root->SetList("windows", list);
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(root);
  return CefWriteJSON(value, JSON_WRITER_DEFAULT);
}

}  // namespace

std::vector<WindowLayout> Read(const std::string& folder) {
  std::vector<WindowLayout> windows;
  if (folder.empty()) return windows;
  std::ifstream file(PathIn(folder), std::ios::binary);
  const std::string json((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
  CefRefPtr<CefValue> value = CefParseJSON(json, JSON_PARSER_RFC);
  CefRefPtr<CefDictionaryValue> root = value ? value->GetDictionary() : nullptr;
  CefRefPtr<CefListValue> list = root ? root->GetList("windows") : nullptr;
  for (size_t i = 0; list && i < list->GetSize(); ++i) {
    CefRefPtr<CefDictionaryValue> item = list->GetDictionary(i);
    CefRefPtr<CefListValue> bounds = item ? item->GetList("bounds") : nullptr;
    CefRefPtr<CefListValue> panes = item ? item->GetList("panes") : nullptr;
    if (!bounds || bounds->GetSize() != 4 || !panes) continue;
    WindowLayout layout;
    layout.bounds = CefRect(bounds->GetInt(0), bounds->GetInt(1), bounds->GetInt(2), bounds->GetInt(3));
    layout.active_pane = item->GetInt("active_pane");
    layout.previews = item->GetBool("previews");
    for (size_t j = 0; j < panes->GetSize(); ++j) {
      CefRefPtr<CefDictionaryValue> pane = panes->GetDictionary(j);
      CefRefPtr<CefListValue> tabs = pane ? pane->GetList("tabs") : nullptr;
      if (!tabs) continue;
      WindowLayout::PaneTabs saved;
      saved.active = pane->GetInt("active");
      saved.weight = pane->GetInt("weight");
      for (size_t k = 0; k < tabs->GetSize(); ++k) {
        CefRefPtr<CefDictionaryValue> tab = tabs->GetDictionary(k);
        if (!tab || tab->GetString("url").empty()) continue;
        saved.tabs.push_back(
            {tab->GetString("url"), tab->GetString("title"), tab->GetString("favicon"), tab->GetString("preview")});
      }
      if (!saved.tabs.empty()) layout.panes.push_back(std::move(saved));
    }
    if (!layout.panes.empty()) windows.push_back(std::move(layout));
  }
  return windows;
}

void Write(const std::string& folder, const std::vector<WindowLayout>& windows, bool now) {
  if (folder.empty()) return;
  if (now) {
    WriteFile(PathIn(folder), Serialize(windows));
  } else {
    CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&WriteFile, PathIn(folder), Serialize(windows)));
  }
}

}  // namespace session
