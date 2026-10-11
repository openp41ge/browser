// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The channel between the browser's UI pages and the browser (UiView in
// app/src/ui): `cefQuery`, which only openp41ge://ui/ pages have.

/** Sends a message ({ type, … }) to the browser. */
export function send(message) {
  window.cefQuery({ request: JSON.stringify(message), onSuccess() {}, onFailure() {} });
}

/** Calls `handler` with each message the browser sends this page. */
export function listen(handler) {
  window.cefQuery({
    request: JSON.stringify({ type: 'listen' }),
    persistent: true,
    onSuccess: (response) => handler(JSON.parse(response)),
    onFailure() {},
  });
}
