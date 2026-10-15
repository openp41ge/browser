// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_AUDIBLE_H_
#define OPENP41GE_EXPLORER_AUDIBLE_H_

#include "include/cef_frame.h"
#include "include/cef_v8.h"

// Whether a tab is playing sound, for its tab's speaker icon (as Chrome
// shows). CEF doesn't say, so each web page's document (every frame's, an
// embedded player's too) watches its own media elements: one playing, not
// muted and not at volume 0 is sound. It tells the browser when that changes
// with a kMessage process message ({ audible: bool }, from its frame), and
// says it's quiet as it goes. The browser counts a tab as playing while any
// of its frames is (BrowserManager). Web Audio isn't seen, nor media outside
// the document (new Audio() never added to it) or in shadow trees.
namespace audible {

constexpr char kMessage[] = "openp41ge.audible";

// Renderer: starts watching `frame`'s new document (`context`, its main
// world).
void Watch(CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context);
// Renderer: the document is going; quiet now, if it wasn't.
void Unwatch(CefRefPtr<CefFrame> frame);

}  // namespace audible

#endif  // OPENP41GE_EXPLORER_AUDIBLE_H_
