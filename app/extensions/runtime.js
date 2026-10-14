// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The extension runtime, page side. The browser runs it in each page, in a
// JavaScript world of each extension's own (an isolated world: it shares
// the page's DOM, not its globals), at the start of every document, before
// the page's own scripts. See plans/2026-10-14-extension-system.md.
//
// This file is one function expression. The browser
// (src/extensions/extension_manager.mm) calls it with:
//   extension  { id, name, version, contentScripts: [{ matches, css,
//              runAtStart, enabled }] }, the CSS as text
//   scripts    for each content script, its JS files as
//              [{ path, run: function }] (each file is a function's body)
//   loadPopout runs packages/popout's core.js in this world
//
// In the top frame of a page whose address matches a content script, it
// adds the script's CSS and runs its JS: straight away for
// "document_start", once the page's DOM is ready for "document_idle".
// Extensions' code finds the browser's API at `openp41ge`.

(extension, scripts, loadPopout) => {
  'use strict';

  // Once per document (the browser can run this again in a document it
  // already ran in: one open before the extension was), and only in the
  // top frame. Marked on the document, not the window: a page's first,
  // blank document hands its window on to the next one of the same origin
  // (a page opened by window.open), and this runs in both. (A property set
  // here is this world's own: the page doesn't see it.)
  if (document.openp41geExtensionRan || window.top !== window) return;
  document.openp41geExtensionRan = true;

  let popoutLoaded = false;
  const api = {
    extension: Object.freeze({ id: extension.id, name: extension.name, version: extension.version }),
    // packages/popout: __openp41ge.popout(), definePreset() and the rest.
    get popout() {
      if (!popoutLoaded) {
        loadPopout();
        popoutLoaded = true;
      }
      return globalThis.__openp41ge;
    },
  };
  // Replaced in each document (configurable), for a window handed on.
  Object.defineProperty(globalThis, 'openp41ge', { value: Object.freeze(api), configurable: true });

  const log = (message, error) => console.error(`[${extension.name} (${extension.id})] ${message}`, error ?? '');

  const toRun = extension.contentScripts
    .map((script, i) => ({ ...script, js: scripts[i] }))
    .filter((script) => script.enabled && script.matches.some((pattern) => matches(pattern, location)));
  if (!toRun.length) return;

  // CSS as constructed style sheets: a page's Content Security Policy
  // doesn't apply to them, as it would to a <style> element.
  for (const script of toRun) {
    for (const text of script.css) {
      try {
        const sheet = new CSSStyleSheet();
        sheet.replaceSync(text);
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
      } catch (error) {
        log('CSS failed', error);
      }
    }
  }

  const run = (script) => {
    for (const file of script.js) {
      try {
        file.run();
      } catch (error) {
        log(`${file.path} failed`, error);
      }
    }
  };
  const whenReady = (fn) =>
    document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', fn, { once: true }) : fn();
  for (const script of toRun) {
    if (script.runAtStart) run(script);
    else whenReady(() => run(script));
  }

  // Chrome's match patterns: "<all_urls>", or scheme://host[:port]/path,
  // where scheme is *, http or https; host is *, *.domain (the domain and
  // its subdomains) or a host name; a pattern without a port matches any
  // port; path is matched against the path and query, * matching anything.
  function matches(pattern, url) {
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
    if (pattern === '<all_urls>') return true;
    const parts = pattern.match(/^(\*|https?):\/\/(\*|(?:\*\.)?[^/*:]+)(?::(\*|\d+))?(\/.*)$/);
    if (!parts) return false;
    const [, scheme, host, port, path] = parts;
    if (scheme !== '*' && `${scheme}:` !== url.protocol) return false;
    const hostname = url.hostname.toLowerCase();
    if (host.startsWith('*.')) {
      const domain = host.slice(2).toLowerCase();
      if (hostname !== domain && !hostname.endsWith(`.${domain}`)) return false;
    } else if (host !== '*' && host.toLowerCase() !== hostname) {
      return false;
    }
    if (port && port !== '*' && port !== (url.port || (url.protocol === 'https:' ? '443' : '80'))) return false;
    const glob = new RegExp(`^${path.split('*').map((s) => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*')}$`);
    return glob.test(url.pathname + url.search);
  }
}
