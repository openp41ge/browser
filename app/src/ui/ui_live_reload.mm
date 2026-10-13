// Copyright (c) 2026 Richard Kielty. MIT License.

#include "ui/ui_live_reload.h"

#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>
#include <sys/stat.h>

namespace ui_live_reload {

namespace {

void OnEvents(ConstFSEventStreamRef stream,
              void* info,
              size_t count,
              void* paths,
              const FSEventStreamEventFlags flags[],
              const FSEventStreamEventId ids[]) {
  // On the main queue, which is CEF's UI thread on macOS.
  (*static_cast<std::function<void()>*>(info))();
}

}  // namespace

std::string SourceDir() {
#if defined(EXPLORER_UI_SOURCE_DIR)
  struct stat info;
  if (stat(EXPLORER_UI_SOURCE_DIR, &info) == 0 && S_ISDIR(info.st_mode)) return EXPLORER_UI_SOURCE_DIR;
#endif
  return std::string();
}

void Watch(std::function<void()> changed) {
  const std::string dir = SourceDir();
  if (dir.empty()) return;
  // For as long as the app runs.
  auto* callback = new std::function<void()>(std::move(changed));
  CFStringRef path = CFStringCreateWithCString(nullptr, dir.c_str(), kCFStringEncodingUTF8);
  CFArrayRef paths = CFArrayCreate(nullptr, reinterpret_cast<const void**>(&path), 1, &kCFTypeArrayCallBacks);
  FSEventStreamContext context = {0, callback, nullptr, nullptr, nullptr};
  // Changes within 0.1s of each other come as one.
  FSEventStreamRef stream = FSEventStreamCreate(nullptr, &OnEvents, &context, paths, kFSEventStreamEventIdSinceNow,
                                                0.1, kFSEventStreamCreateFlagNone);
  CFRelease(paths);
  CFRelease(path);
  FSEventStreamSetDispatchQueue(stream, dispatch_get_main_queue());
  FSEventStreamStart(stream);
}

}  // namespace ui_live_reload
