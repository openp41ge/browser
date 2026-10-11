// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The command palette: type an address or a search; Return goes there,
// Escape (or clicking elsewhere) dismisses.

import { listen, send } from './channel.js';

const input = document.getElementById('input');
const SEARCH_URL = 'https://www.google.com/search?q=';

/** What was typed, as a URL to load: an address, or else a search. */
function toUrl(text) {
  const input = text.trim();
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(input) || /^(about|data|file):/i.test(input)) return input;
  const looksLikeHost =
    !/\s/.test(input) && (/^localhost(:\d+)?(\/|$)/i.test(input) || /^[^/\s]+\.[^/\s]{2,}/.test(input));
  if (looksLikeHost) {
    const isLocal = /^(localhost|127\.|\[::1\]|[^/]+\.(localhost|test))/i.test(input);
    return `${isLocal ? 'http' : 'https'}://${input}`;
  }
  return SEARCH_URL + encodeURIComponent(input);
}

document.getElementById('form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (input.value.trim()) send({ type: 'go', url: toUrl(input.value) });
});

input.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') send({ type: 'dismiss' });
});

listen((message) => {
  if (message.type !== 'open') return;
  input.value = message.text;
  input.focus();
  input.select();
});
