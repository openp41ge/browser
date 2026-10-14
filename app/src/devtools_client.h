// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_DEVTOOLS_CLIENT_H_
#define OPENP41GE_EXPLORER_DEVTOOLS_CLIENT_H_

#include <functional>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_devtools_message_observer.h"

// Calls DevTools protocol methods on pages and hands back their results,
// and passes on the events pages send. Pages are attached once created and
// detached before they close.
class DevToolsClient : public CefDevToolsMessageObserver {
 public:
  using ResultCallback = std::function<void(CefRefPtr<CefDictionaryValue>)>;
  using ValueCallback = std::function<void(CefRefPtr<CefValue>)>;
  using EventHandler = std::function<void(CefRefPtr<CefBrowser>, CefRefPtr<CefDictionaryValue> params)>;

  void Attach(CefRefPtr<CefBrowser> browser);
  void Detach(CefRefPtr<CefBrowser> browser);

  // Calls `method`; the callback (optional) gets the parsed result, or null
  // on failure. Callbacks run on the UI thread, after this call returns.
  void Call(CefRefPtr<CefBrowser> browser,
            const std::string& method,
            CefRefPtr<CefDictionaryValue> params,
            ResultCallback callback = nullptr);

  struct EvaluateOptions {
    // Runs as if the user had just clicked: needed for APIs that require a
    // user gesture, such as opening a Document Picture-in-Picture window.
    bool user_gesture = false;
    // Waits for a returned promise and passes on its value.
    bool await_promise = false;
  };
  // Evaluates `expression` in the page's main frame; the callback (optional)
  // gets its value, or null.
  void Evaluate(CefRefPtr<CefBrowser> browser,
                const std::string& expression,
                EvaluateOptions options,
                ValueCallback callback = nullptr);

  // Calls `handler` with each `method` event from any page (e.g.
  // "Runtime.bindingCalled"), on the UI thread. A page sends a domain's
  // events once the domain is on (or the method that sends them was
  // called).
  void OnEvent(const std::string& method, EventHandler handler);

  // CefDevToolsMessageObserver:
  void OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser,
                              int message_id,
                              bool success,
                              const void* result,
                              size_t result_size) override;
  void OnDevToolsEvent(CefRefPtr<CefBrowser> browser,
                       const CefString& method,
                       const void* params,
                       size_t params_size) override;

 private:
  std::map<int, CefRefPtr<CefRegistration>> registrations_;  // By browser id.
  std::map<std::pair<int, int>, ResultCallback> pending_;     // By (browser id, message id).
  std::map<std::string, std::vector<EventHandler>> handlers_;  // By method.

  IMPLEMENT_REFCOUNTING(DevToolsClient);
};

#endif  // OPENP41GE_EXPLORER_DEVTOOLS_CLIENT_H_
