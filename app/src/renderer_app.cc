// Copyright (c) 2026 Richard Kielty. MIT License.

#include "renderer_app.h"

namespace {

// Written by BrowserManager::NewPageExtraInfo().
constexpr char kInitScriptKey[] = "openp41ge.init_script";

}  // namespace

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
  auto it = init_scripts_.find(browser->GetIdentifier());
  if (it == init_scripts_.end() || !frame->IsMain()) return;
  CefRefPtr<CefV8Value> result;
  CefRefPtr<CefV8Exception> exception;
  context->Eval(it->second, frame->GetURL(), 0, result, exception);
}
