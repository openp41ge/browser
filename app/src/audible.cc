// Copyright (c) 2026 Richard Kielty. MIT License.

#include "audible.h"

#include <map>
#include <string>

namespace audible {
namespace {

// Called with each media element event (they don't bubble, so caught on the
// way down), it works out whether any is playing sound and calls `report`
// when that changes. A closure: nothing is left in the page's globals.
constexpr char kWatcher[] = R"js(
(report) => {
  const media = new Set();
  let audible = false;
  const update = (event) => {
    if (!(event.target instanceof HTMLMediaElement)) return;
    media.add(event.target);
    let now = false;
    for (const m of media) {
      if (!m.isConnected) media.delete(m);
      else if (!m.paused && !m.ended && !m.muted && m.volume > 0) now = true;
    }
    if (now !== audible) report((audible = now));
  };
  for (const type of ['play', 'playing', 'pause', 'ended', 'volumechange', 'emptied', 'abort', 'error']) {
    addEventListener(type, update, true);
  }
}
)js";

void Send(CefRefPtr<CefFrame> frame, bool audible) {
  CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(kMessage);
  message->GetArgumentList()->SetBool(0, audible);
  frame->SendProcessMessage(PID_BROWSER, message);
}

// What the watcher calls; keeps the frame's last word, to say it's quiet
// as the document goes.
class Reporter : public CefV8Handler {
 public:
  explicit Reporter(CefRefPtr<CefFrame> frame) : frame_(frame) {}
  bool audible() const { return audible_; }

  bool Execute(const CefString& name,
               CefRefPtr<CefV8Value> object,
               const CefV8ValueList& arguments,
               CefRefPtr<CefV8Value>& retval,
               CefString& exception) override {
    const bool audible = !arguments.empty() && arguments[0]->IsBool() && arguments[0]->GetBoolValue();
    if (audible == audible_) return true;
    audible_ = audible;
    Send(frame_, audible);
    return true;
  }

 private:
  CefRefPtr<CefFrame> frame_;
  bool audible_ = false;

  IMPLEMENT_REFCOUNTING(Reporter);
};

// By frame (one document at a time in each).
std::map<std::string, CefRefPtr<Reporter>>& Reporters() {
  static std::map<std::string, CefRefPtr<Reporter>> reporters;
  return reporters;
}

}  // namespace

void Watch(CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context) {
  CefRefPtr<CefV8Value> watcher;
  CefRefPtr<CefV8Exception> exception;
  if (!context->Eval(kWatcher, "", 0, watcher, exception) || !watcher->IsFunction()) return;
  Unwatch(frame);
  CefRefPtr<Reporter> reporter = new Reporter(frame);
  Reporters()[frame->GetIdentifier()] = reporter;
  watcher->ExecuteFunctionWithContext(context, nullptr, {CefV8Value::CreateFunction("report", reporter)});
}

void Unwatch(CefRefPtr<CefFrame> frame) {
  auto it = Reporters().find(frame->GetIdentifier());
  if (it == Reporters().end()) return;
  if (it->second->audible()) Send(frame, false);
  Reporters().erase(it);
}

}  // namespace audible
