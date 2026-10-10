// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#include "explorer_handler.h"

#include "include/base/cef_callback.h"
#include "include/cef_app.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

namespace {

ExplorerHandler* g_instance = nullptr;

}  // namespace

ExplorerHandler::ExplorerHandler() {
  DCHECK(!g_instance);
  g_instance = this;
}

ExplorerHandler::~ExplorerHandler() {
  g_instance = nullptr;
}

ExplorerHandler* ExplorerHandler::GetInstance() {
  return g_instance;
}

void ExplorerHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  browsers_.push_back(browser);
}

bool ExplorerHandler::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  // Closing the last browser ends the app; see DoClose() in cef_life_span_handler.h.
  if (browsers_.size() == 1) {
    is_closing_ = true;
  }
  return false;  // Let the window close normally.
}

void ExplorerHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  browsers_.remove_if([&](const CefRefPtr<CefBrowser>& b) { return b->IsSame(browser); });
  if (browsers_.empty()) {
    CefQuitMessageLoop();
  }
}

void ExplorerHandler::CloseAllBrowsers(bool force_close) {
  if (!CefCurrentlyOn(TID_UI)) {
    CefPostTask(TID_UI, base::BindOnce(&ExplorerHandler::CloseAllBrowsers, this, force_close));
    return;
  }
  for (const auto& browser : browsers_) {
    browser->GetHost()->CloseBrowser(force_close);
  }
}
