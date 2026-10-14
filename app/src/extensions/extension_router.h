// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_ROUTER_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_ROUTER_H_

#include "include/wrapper/cef_message_router.h"

// The message channel of extension pages (ExtensionManager), apart from the
// browser UI's (`cefQuery`): its own JavaScript functions and process
// messages, in both processes.
namespace extension_router {

inline CefMessageRouterConfig Config() {
  CefMessageRouterConfig config;
  config.js_query_function = "openp41geExtensionQuery";
  config.js_cancel_function = "openp41geExtensionQueryCancel";
  return config;
}

}  // namespace extension_router

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_EXTENSION_ROUTER_H_
