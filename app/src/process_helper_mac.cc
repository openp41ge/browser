// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

// Entry point for CEF's helper processes (renderer, GPU, utility...).

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

#include "renderer_app.h"

#if defined(CEF_USE_SANDBOX)
#include "include/cef_sandbox_mac.h"
#endif

int main(int argc, char* argv[]) {
#if defined(CEF_USE_SANDBOX)
  CefScopedSandboxContext sandbox_context;
  if (!sandbox_context.Initialize(argc, argv)) {
    return 1;
  }
#endif

  // The macOS sandbox requires loading the CEF framework at runtime.
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInHelper()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);
  CefRefPtr<CefApp> app(new RendererApp());
  return CefExecuteProcess(main_args, app, nullptr);
}
