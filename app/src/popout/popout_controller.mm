// Copyright (c) 2026 Richard Kielty. MIT License.

#include "popout/popout_controller.h"

#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"

#include "popout/popout_scripts.h"

namespace {

std::string ToJson(CefRefPtr<CefValue> value) {
  return CefWriteJSON(value, JSON_WRITER_DEFAULT).ToString();
}

std::string OptionsJson(const PopoutController::Options& options) {
  CefRefPtr<CefDictionaryValue> dict = CefDictionaryValue::Create();
  dict->SetString("selector", options.selector);
  dict->SetBool("play", options.play);
  if (options.place) {
    CefRefPtr<CefListValue> place = CefListValue::Create();
    place->SetInt(0, options.place->x);
    place->SetInt(1, options.place->y);
    place->SetInt(2, options.place->width);
    dict->SetList("place", place);
  }
  CefRefPtr<CefValue> value = CefValue::Create();
  value->SetDictionary(dict);
  return ToJson(value);
}

}  // namespace

// The pop-out window's client: follows its life span.
class PopoutController::WindowClient : public CefClient, public CefLifeSpanHandler {
 public:
  explicit WindowClient(PopoutController* controller) : controller_(controller) {}

  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }

  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
    controller_->OnWindowCreated(browser);
  }
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override { controller_->OnWindowClosed(); }

 private:
  // The controller lives as long as the app, and owns this client.
  PopoutController* controller_;
  IMPLEMENT_REFCOUNTING(WindowClient);
};

PopoutController::PopoutController(CefRefPtr<DevToolsClient> devtools, Observer* observer)
    : devtools_(devtools), observer_(observer), window_client_(new WindowClient(this)) {}

void PopoutController::PopOut(CefRefPtr<CefBrowser> page, const Options& options, DoneCallback done) {
  CEF_REQUIRE_UI_THREAD();
  if (IsOpen() || pending_source_) {
    if (done) done("already-open");
    return;
  }
  // Document PiP needs a user gesture; run it as one.
  devtools_->Evaluate(page, popout_scripts::Library() + "\n__openp41ge.popout(" + OptionsJson(options) + ")",
                      {.user_gesture = true, .await_promise = true},
                      [done](CefRefPtr<CefValue> outcome) {
                        if (!done) return;
                        done(outcome && outcome->GetType() == VTYPE_STRING ? outcome->GetString().ToString()
                                                                         : "failed");
                      });
}

void PopoutController::Close() {
  CEF_REQUIRE_UI_THREAD();
  if (window_) window_->GetHost()->CloseBrowser(false);
}

void PopoutController::Toggle(CefRefPtr<CefBrowser> page) {
  if (IsOpen()) {
    Close();
  } else if (page) {
    PopOut(page, {}, [](const std::string& outcome) {
      LOG_IF(WARNING, outcome != "opened") << "Pop-out: " << outcome;
    });
  }
}

std::string PopoutController::ScriptForNewPages() const {
  return IsOpen() ? popout_scripts::HoldAutoplay() : std::string();
}

bool PopoutController::OnBeforePopup(CefRefPtr<CefBrowser> opener,
                                     cef_window_open_disposition_t disposition,
                                     CefRefPtr<CefClient>& client) {
  CEF_REQUIRE_UI_THREAD();
  if (disposition != CEF_WOD_NEW_PICTURE_IN_PICTURE) return false;
  pending_source_ = opener;
  client = window_client_;
  return true;
}

void PopoutController::OnWindowCreated(CefRefPtr<CefBrowser> window) {
  window_ = window;
  source_ = pending_source_;
  pending_source_ = nullptr;
  if (observer_) observer_->OnPopoutOpened(source_);
}

void PopoutController::OnWindowClosed() {
  CefRefPtr<CefBrowser> source = source_;
  window_ = nullptr;
  source_ = nullptr;
  if (observer_) observer_->OnPopoutClosed(source);
}
