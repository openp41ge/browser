// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#include "explorer_app.h"

#include <string>

#include "include/cef_command_line.h"
#include "include/wrapper/cef_helpers.h"

void ExplorerApp::OnBeforeCommandLineProcessing(const CefString& process_type,
                                                CefRefPtr<CefCommandLine> command_line) {
  if (!process_type.empty()) return;
  // Pages keep running at full speed while hidden or minimized: a popped-out
  // element's page is often in the background.
  command_line->AppendSwitch("disable-background-timer-throttling");
  command_line->AppendSwitch("disable-renderer-backgrounding");
  command_line->AppendSwitch("disable-backgrounding-occluded-windows");
}

void ExplorerApp::OnContextInitialized() {
  CEF_REQUIRE_UI_THREAD();
  manager_ = new BrowserManager();
  // `--url=<url>` opens a specific page instead of the new tab page.
  manager_->OpenPageWindow(CefCommandLine::GetGlobalCommandLine()->GetSwitchValue("url"));
}

CefRefPtr<CefClient> ExplorerApp::GetDefaultClient() {
  // Used for browsers CEF creates itself.
  return manager_;
}
