// Copyright (c) 2026 Richard Kielty. MIT License.

#include "devtools_client.h"

#include <dispatch/dispatch.h>

#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

void DevToolsClient::Attach(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  registrations_[browser->GetIdentifier()] = browser->GetHost()->AddDevToolsMessageObserver(this);
}

void DevToolsClient::Detach(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  const int id = browser->GetIdentifier();
  registrations_.erase(id);
  for (auto it = pending_.begin(); it != pending_.end();) {
    it = it->first.first == id ? pending_.erase(it) : std::next(it);
  }
}

void DevToolsClient::Call(CefRefPtr<CefBrowser> browser,
                          const std::string& method,
                          CefRefPtr<CefDictionaryValue> params,
                          ResultCallback callback) {
  CEF_REQUIRE_UI_THREAD();
  const int message_id = browser->GetHost()->ExecuteDevToolsMethod(0, method, params);
  if (message_id && callback) {
    pending_[{browser->GetIdentifier(), message_id}] = std::move(callback);
  } else if (!message_id && callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
      callback(nullptr);
    });
  }
}

void DevToolsClient::Evaluate(CefRefPtr<CefBrowser> browser,
                              const std::string& expression,
                              EvaluateOptions options,
                              ValueCallback callback) {
  CefRefPtr<CefDictionaryValue> params = CefDictionaryValue::Create();
  params->SetString("expression", expression);
  params->SetBool("returnByValue", true);
  if (options.user_gesture) params->SetBool("userGesture", true);
  if (options.await_promise) params->SetBool("awaitPromise", true);
  if (!callback) {
    Call(browser, "Runtime.evaluate", params);
    return;
  }
  Call(browser, "Runtime.evaluate", params, [callback](CefRefPtr<CefDictionaryValue> result) {
    // {"result": {"type": ..., "value": ...}}
    CefRefPtr<CefDictionaryValue> inner = result ? result->GetDictionary("result") : nullptr;
    callback(inner && inner->HasKey("value") ? inner->GetValue("value") : nullptr);
  });
}

void DevToolsClient::OnDevToolsMethodResult(CefRefPtr<CefBrowser> browser,
                                            int message_id,
                                            bool success,
                                            const void* result,
                                            size_t result_size) {
  auto it = pending_.find({browser->GetIdentifier(), message_id});
  if (it == pending_.end()) return;
  ResultCallback callback = std::move(it->second);
  pending_.erase(it);

  CefRefPtr<CefDictionaryValue> parsed_result;
  if (success) {
    CefRefPtr<CefValue> parsed = CefParseJSON(result, result_size, JSON_PARSER_RFC);
    parsed_result = parsed ? parsed->GetDictionary() : nullptr;
  }
  // Run it after this notification returns, so the callback can make
  // further calls.
  dispatch_async(dispatch_get_main_queue(), ^{
    callback(parsed_result);
  });
}
