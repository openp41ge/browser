// Copyright (c) 2026 Richard Kielty. MIT License.
//
// What someone typed into an address field, as a URL to load.

const SEARCH_URL = 'https://www.google.com/search?q=';

/** An address as typed (with or without a scheme) as a URL, or null if it isn't one. */
export function toAddress(text) {
  const input = text.trim();
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(input) || /^(about|data|file):/i.test(input)) return input;
  const looksLikeHost =
    !/\s/.test(input) && (/^localhost(:\d+)?(\/|$)/i.test(input) || /^[^/\s]+\.[^/\s]{2,}/.test(input));
  if (!looksLikeHost) return null;
  const isLocal = /^(localhost|127\.|\[::1\]|[^/]+\.(localhost|test))/i.test(input);
  return `${isLocal ? 'http' : 'https'}://${input}`;
}

/** An address, or else a search. */
export function toUrl(text) {
  return toAddress(text) ?? SEARCH_URL + encodeURIComponent(text.trim());
}
