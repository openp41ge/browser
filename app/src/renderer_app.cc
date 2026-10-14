// Copyright (c) 2026 Richard Kielty. MIT License.

#include "renderer_app.h"

#include "extensions/extension_router.h"
#include "extensions/extension_scheme.h"
#include "ui/ui_scheme.h"

namespace {

// Written by BrowserManager::NewPageExtraInfo().
constexpr char kInitScriptKey[] = "openp41ge.init_script";

}  // namespace

RendererApp::RendererApp()
    : extension_router_(CefMessageRouterRendererSide::Create(extension_router::Config())) {}

void RendererApp::OnRegisterCustomSchemes(CefRawPtr<CefSchemeRegistrar> registrar) {
  ui_scheme::Register(registrar);
  extension_scheme::Register(registrar);
}

void RendererApp::OnBrowserCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> extra_info) {
  if (extra_info && extra_info->HasKey(kInitScriptKey)) {
    init_scripts_[browser->GetIdentifier()] = extra_info->GetString(kInitScriptKey);
  }
}

void RendererApp::OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) {
  init_scripts_.erase(browser->GetIdentifier());
}

void RendererApp::OnContextCreated(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   CefRefPtr<CefV8Context> context) {
  if (ui_scheme::IsUiUrl(frame->GetURL())) router_->OnContextCreated(browser, frame, context);
  if (frame->IsMain() &&
      (!extension_scheme::IdOf(frame->GetURL()).empty() || ui_scheme::IsExtensionsUrl(frame->GetURL()))) {
    extension_router_->OnContextCreated(browser, frame, context);
  }

  auto it = init_scripts_.find(browser->GetIdentifier());
  if (it == init_scripts_.end() || !frame->IsMain()) return;
  CefRefPtr<CefV8Value> result;
  CefRefPtr<CefV8Exception> exception;
  context->Eval(it->second, frame->GetURL(), 0, result, exception);
}

void RendererApp::OnContextReleased(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    CefRefPtr<CefV8Context> context) {
  router_->OnContextReleased(browser, frame, context);
  extension_router_->OnContextReleased(browser, frame, context);
}

bool RendererApp::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser,
                                           CefRefPtr<CefFrame> frame,
                                           CefProcessId source_process,
                                           CefRefPtr<CefProcessMessage> message) {
  return router_->OnProcessMessageReceived(browser, frame, source_process, message) ||
         extension_router_->OnProcessMessageReceived(browser, frame, source_process, message);
}
