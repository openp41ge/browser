// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_RENDERER_APP_H_
#define OPENP41GE_EXPLORER_RENDERER_APP_H_

#include <map>
#include <string>

#include "include/cef_app.h"
#include "include/wrapper/cef_message_router.h"

// Callbacks for the helper processes (the same CefApp in every process type).
//
// Renderer:
// - A page created with an init script in its extra info (see
//   BrowserManager::NewPageExtraInfo) runs it in each new document of its
//   main frame, before the page's own scripts.
// - The browser's own UI pages (openp41ge://ui/) get `cefQuery`, the
//   message channel to the browser (CefMessageRouter). Web pages don't.
// - Extension pages (openp41ge-extension://, extension_scheme.h) and the
//   Extensions page (openp41ge://extensions/) get `openp41geExtensionQuery`,
//   a channel of their own (ExtensionManager), in their main frame only.
class RendererApp : public CefApp, public CefRenderProcessHandler {
 public:
  RendererApp();

  // CefApp:
  void OnRegisterCustomSchemes(CefRawPtr<CefSchemeRegistrar> registrar) override;
  CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { return this; }

  // CefRenderProcessHandler:
  void OnBrowserCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> extra_info) override;
  void OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) override;
  void OnContextCreated(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        CefRefPtr<CefV8Context> context) override;
  void OnContextReleased(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         CefRefPtr<CefV8Context> context) override;
  bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                CefProcessId source_process,
                                CefRefPtr<CefProcessMessage> message) override;

 private:
  CefRefPtr<CefMessageRouterRendererSide> router_ =
      CefMessageRouterRendererSide::Create(CefMessageRouterConfig());
  CefRefPtr<CefMessageRouterRendererSide> extension_router_;
  std::map<int, std::string> init_scripts_;  // By browser id.

  IMPLEMENT_REFCOUNTING(RendererApp);
};

#endif  // OPENP41GE_EXPLORER_RENDERER_APP_H_
