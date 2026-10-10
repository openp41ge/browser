// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#ifndef OPENP41GE_EXPLORER_APP_H_
#define OPENP41GE_EXPLORER_APP_H_

#include "include/cef_app.h"

// Browser-process callbacks: opens the first window once CEF is ready.
class ExplorerApp : public CefApp, public CefBrowserProcessHandler {
 public:
  ExplorerApp() = default;

  // CefApp:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
    return this;
  }

  // CefBrowserProcessHandler:
  void OnContextInitialized() override;
  CefRefPtr<CefClient> GetDefaultClient() override;

 private:
  IMPLEMENT_REFCOUNTING(ExplorerApp);
};

#endif  // OPENP41GE_EXPLORER_APP_H_
