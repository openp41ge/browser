// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_RENDERER_APP_H_
#define OPENP41GE_EXPLORER_RENDERER_APP_H_

#include <map>
#include <string>

#include "include/cef_app.h"

// Renderer-process callbacks. A page created with an init script in its
// extra info (see BrowserManager::NewPageExtraInfo) runs it in each new
// document of its main frame, before the page's own scripts.
class RendererApp : public CefApp, public CefRenderProcessHandler {
 public:
  RendererApp() = default;

  // CefApp:
  CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { return this; }

  // CefRenderProcessHandler:
  void OnBrowserCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> extra_info) override;
  void OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) override;
  void OnContextCreated(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        CefRefPtr<CefV8Context> context) override;

 private:
  std::map<int, std::string> init_scripts_;  // By browser id.

  IMPLEMENT_REFCOUNTING(RendererApp);
};

#endif  // OPENP41GE_EXPLORER_RENDERER_APP_H_
