// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#include "explorer_app.h"

#include <string>

#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/wrapper/cef_helpers.h"

#include "explorer_handler.h"

namespace {

constexpr char kStartUrl[] = "chrome://newtab/";

}  // namespace

void ExplorerApp::OnContextInitialized() {
  CEF_REQUIRE_UI_THREAD();

  CefRefPtr<ExplorerHandler> handler(new ExplorerHandler());

  // `--url=<url>` opens a specific page instead of the new tab page.
  std::string url = CefCommandLine::GetGlobalCommandLine()->GetSwitchValue("url");
  if (url.empty()) {
    url = kStartUrl;
  }

  // A Chrome-style browser without a parent view gets a full Chrome window:
  // tab strip, toolbar, menus and settings.
  CefWindowInfo window_info;
  window_info.runtime_style = CEF_RUNTIME_STYLE_CHROME;

  CefBrowserSettings browser_settings;
  CefBrowserHost::CreateBrowser(window_info, handler, url, browser_settings,
                                nullptr, nullptr);
}

CefRefPtr<CefClient> ExplorerApp::GetDefaultClient() {
  // Used for browsers created by Chrome's own UI (new tabs and windows).
  return ExplorerHandler::GetInstance();
}
