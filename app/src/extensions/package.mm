// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/package.h"

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

#include <filesystem>
#include <fstream>
#include <sstream>

namespace extension_package {

namespace {

namespace fs = std::filesystem;

// Runs `tool` with `args`; its exit status and standard output.
int Run(NSString* tool, NSArray<NSString*>* args, std::string* output) {
  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:tool];
  task.arguments = args;
  NSPipe* out = [NSPipe pipe];
  task.standardOutput = out;
  task.standardError = [NSFileHandle fileHandleWithNullDevice];
  NSError* error = nil;
  if (![task launchAndReturnError:&error]) return -1;
  NSData* data = [out.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (output) output->assign(static_cast<const char*>(data.bytes), data.length);
  return task.terminationStatus;
}

std::string Check(const std::string& zip_path) {
  // Every entry's name.
  std::string names;
  if (Run(@"/usr/bin/zipinfo", @[ @"-1", @(zip_path.c_str()) ], &names) != 0) return "it isn't a zip file";
  std::istringstream lines(names);
  size_t count = 0;
  for (std::string name; std::getline(lines, name);) {
    if (name.empty()) continue;
    ++count;
    const fs::path path(name);
    bool climbs = false;
    for (const fs::path& part : path) climbs |= part == "..";
    if (path.is_absolute() || climbs || name.find('\\') != std::string::npos) {
      return "it has a file outside its folder (\"" + name + "\")";
    }
  }
  if (!count) return "it's empty";
  // Each entry's kind: the first letter of its mode ('-' a file, 'd' a
  // folder; 'l' a link).
  std::string listing;
  if (Run(@"/usr/bin/zipinfo", @[ @"-s", @(zip_path.c_str()) ], &listing) != 0) return "it isn't a zip file";
  std::istringstream rows(listing);
  for (std::string row; std::getline(rows, row);) {
    if (row.size() < 10 || !(row[0] == '-' || row[0] == 'd' || row[0] == 'l')) continue;  // Header, totals.
    if (row[1] != 'r' && row[1] != '-') continue;
    if (row[0] == 'l') return "it has a link in it";
  }
  return std::string();
}

}  // namespace

std::string Sha256(const std::string& bytes) {
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(bytes.data(), static_cast<CC_LONG>(bytes.size()), digest);
  static constexpr char kHex[] = "0123456789abcdef";
  std::string hex;
  for (unsigned char byte : digest) {
    hex += kHex[byte >> 4];
    hex += kHex[byte & 0xf];
  }
  return hex;
}

std::string Unpack(const std::string& zip, const std::string& folder) {
  std::error_code error;
  if (fs::exists(folder, error)) return "the folder to unpack into exists";
  fs::create_directories(folder, error);
  if (error) return "couldn't make " + folder;
  const std::string zip_path = folder + ".zip";
  {
    std::ofstream stream(zip_path, std::ios::binary | std::ios::trunc);
    stream << zip;
    if (!stream) return "couldn't write " + zip_path;
  }
  std::string problem = Check(zip_path);
  if (problem.empty() &&
      Run(@"/usr/bin/unzip", @[ @"-q", @"-o", @(zip_path.c_str()), @"-d", @(folder.c_str()) ], nullptr) != 0) {
    problem = "it couldn't be unpacked";
  }
  fs::remove(zip_path, error);
  // And nothing unpacked is a link (whatever the listing said).
  for (auto it = fs::recursive_directory_iterator(folder, error); problem.empty() && !error && it != fs::end(it);
       it.increment(error)) {
    if (it->is_symlink()) problem = "it has a link in it";
  }
  if (!problem.empty()) fs::remove_all(folder, error);
  return problem;
}

}  // namespace extension_package
