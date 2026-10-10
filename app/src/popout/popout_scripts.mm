// Copyright (c) 2026 Richard Kielty. MIT License.

#include "popout/popout_scripts.h"

#import <Foundation/Foundation.h>

#include "include/base/cef_logging.h"

namespace popout_scripts {
namespace {

NSString* ScriptsDir() {
  return [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"popout"];
}

std::string Read(NSString* path) {
  NSString* text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  LOG_IF(ERROR, !text) << "Missing pop-out script: " << path.UTF8String;
  return text ? std::string(text.UTF8String) : std::string();
}

}  // namespace

const std::string& Library() {
  static const std::string library = Read([ScriptsDir() stringByAppendingPathComponent:@"core.js"]);
  return library;
}

const std::string& HoldAutoplay() {
  static const std::string script = Read([ScriptsDir() stringByAppendingPathComponent:@"hold-autoplay.js"]);
  return script;
}

}  // namespace popout_scripts
