// Copyright (c) 2026 Richard Kielty. MIT License.
// Adapted from CEF's cefsimple sample (BSD-3-Clause, the CEF Authors).

#ifndef OPENP41GE_EXPLORER_HANDLER_H_
#define OPENP41GE_EXPLORER_HANDLER_H_

#include <list>

#include "include/cef_client.h"

// Browser-level callbacks shared by every tab and window. Tracks open
// browsers so the app can quit once the last one closes.
class ExplorerHandler : public CefClient, public CefLifeSpanHandler {
 public:
  ExplorerHandler();
  ~ExplorerHandler() override;

  static ExplorerHandler* GetInstance();

  // CefClient:
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }

  // CefLifeSpanHandler:
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  // Asks every open browser to close (e.g. on Cmd+Q).
  void CloseAllBrowsers(bool force_close);
  bool IsClosing() const { return is_closing_; }

 private:
  std::list<CefRefPtr<CefBrowser>> browsers_;  // UI thread only.
  bool is_closing_ = false;

  IMPLEMENT_REFCOUNTING(ExplorerHandler);
};

#endif  // OPENP41GE_EXPLORER_HANDLER_H_
