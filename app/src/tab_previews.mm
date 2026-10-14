// Copyright (c) 2026 Richard Kielty. MIT License.

#include "tab_previews.h"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <map>
#include <mutex>

#include "include/base/cef_callback.h"
#include "include/cef_task.h"
#include "include/wrapper/cef_closure_task.h"

namespace tab_previews {

namespace {

constexpr char kFolder[] = "Tab Previews";
constexpr char kExtension[] = ".jpg";
constexpr size_t kTokenLength = 16;

std::string g_folder;  // UI thread.
std::mutex g_lock;
std::map<std::string, std::string>& Pictures() {  // Under g_lock.
  static std::map<std::string, std::string> pictures;
  return pictures;
}

std::string PathOf(const std::string& folder, const std::string& token) {
  return folder + "/" + token + kExtension;
}

void WriteFile(const std::string& folder, const std::string& token, const std::string& jpeg) {
  namespace fs = std::filesystem;
  std::error_code error;
  fs::create_directories(folder, error);
  const std::string path = PathOf(folder, token);
  const std::string temporary = path + ".partial";
  {
    std::ofstream file(temporary, std::ios::binary | std::ios::trunc);
    file << jpeg;
    if (!file) return;
  }
  fs::rename(temporary, path, error);
}

// Only ever our own pictures: files named <token>.jpg in our folder.
void DeleteAllBut(const std::string& folder, const std::set<std::string>& keep) {
  namespace fs = std::filesystem;
  std::error_code error;
  for (const fs::directory_entry& entry : fs::directory_iterator(folder, error)) {
    const fs::path path = entry.path();
    if (path.extension() != kExtension || !IsToken(path.stem().string())) continue;
    if (!keep.count(path.stem().string())) fs::remove(path, error);
  }
}

}  // namespace

void Init(const std::string& profile_folder) {
  g_folder = profile_folder.empty() ? std::string() : profile_folder + "/" + kFolder;
}

std::string NewToken() {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string token(kTokenLength, '0');
  for (char& c : token) c = kHex[arc4random_uniform(16)];
  return token;
}

void Put(const std::string& token, std::string jpeg, bool keep) {
  if (!IsToken(token)) return;
  if (keep && !g_folder.empty()) CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&WriteFile, g_folder, token, jpeg));
  std::lock_guard<std::mutex> lock(g_lock);
  Pictures()[token] = std::move(jpeg);
}

bool Load(const std::string& token) {
  if (!IsToken(token) || g_folder.empty()) return false;
  std::ifstream file(PathOf(g_folder, token), std::ios::binary);
  std::string jpeg((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
  if (jpeg.empty()) return false;
  std::lock_guard<std::mutex> lock(g_lock);
  Pictures()[token] = std::move(jpeg);
  return true;
}

std::string Get(const std::string& token) {
  std::lock_guard<std::mutex> lock(g_lock);
  auto it = Pictures().find(token);
  return it == Pictures().end() ? std::string() : it->second;
}

void Forget(const std::string& token) {
  std::lock_guard<std::mutex> lock(g_lock);
  Pictures().erase(token);
}

void KeepOnly(std::set<std::string> tokens) {
  if (g_folder.empty()) return;
  // After any picture being written (the same thread, in order).
  CefPostTask(TID_FILE_USER_BLOCKING, base::BindOnce(&DeleteAllBut, g_folder, std::move(tokens)));
}

bool IsToken(const std::string& token) {
  if (token.size() != kTokenLength) return false;
  for (char c : token) {
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
  }
  return true;
}

}  // namespace tab_previews
