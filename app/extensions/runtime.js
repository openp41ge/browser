// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The extension runtime, page side. The browser runs it in each page, in a
// JavaScript world of each extension's own (an isolated world: it shares
// the page's DOM, not its globals), at the start of every document, before
// the page's own scripts. See plans/2026-10-14-extension-system.md.
//
// This file is one function expression. The browser
// (src/extensions/extension_manager.mm) calls it with:
//   extension  { id, name, version, binding, features: [{ id, name,
//              enabled }], contentScripts: [{ matches, css, runAtStart,
//              enabled }], config?: { schema, values } }, the CSS as text;
//              `enabled` as the user set the feature; `values` the user's
//              settings, as stored; `binding` the name of the function this
//              world has for sending to the browser (ExtensionManager)
//   scripts    for each content script, its JS files as
//              [{ path, run: function }] (each file is a function's body)
//   loadPopout runs packages/popout's core.js in this world
//   loadSettings returns settings.js's helpers (the code editor's config
//              logic, and reading settings with it)
//   messages   messages.js (feature hosts)
//
// In the top frame of a page whose address matches a content script, it
// adds the script's CSS and runs its JS: straight away for
// "document_start", once the page's DOM is ready for "document_idle".
// Extensions' code finds the browser's API at `openp41ge`.
//
// Settings (settings.js): the user's values merged over the schema's
// defaults, as the code editor does. A stored value that doesn't fit the
// schema (say, after an update changed it) is left out, so its default
// applies. An extension with a required setting that has no value (no
// default, and the user hasn't set it) needs setup: its content scripts
// don't run. Nor do they if its schema is broken. Secret settings are never
// given to content scripts. When the settings change (an extension page
// saved them), the browser calls `__openp41geSettingsChanged` in this world
// with the user's new values, and `openp41ge.config.onChange` callbacks get
// the new settings; content scripts that didn't run (setup was needed) run
// from the next page on.

// Feature hosts and openPage (messages.js) go to the browser through
// `binding`, which the browser adds only to this extension's world; it
// answers by calling `__openp41geReply`, and delivers other tabs' and
// pages' broadcasts by calling `__openp41geDeliver`.

(extension, scripts, loadPopout, loadSettings, messages) => {
  'use strict';

  // Once per document (the browser can run this again in a document it
  // already ran in: one open before the extension was), and only in the
  // top frame. Marked on the document, not the window: a page's first,
  // blank document hands its window on to the next one of the same origin
  // (a page opened by window.open), and this runs in both. (A property set
  // here is this world's own: the page doesn't see it.)
  if (document.openp41geExtensionRan || window.top !== window) return;
  document.openp41geExtensionRan = true;

  const log = (message, error) => console.error(`[${extension.name} (${extension.id})] ${message}`, error ?? '');

  const toRun = extension.contentScripts
    .map((script, i) => ({ ...script, js: scripts[i] }))
    .filter((script) => script.enabled && script.matches.some((pattern) => matches(pattern, location)));
  if (!toRun.length) return;

  const settingsLib = extension.config ? loadSettings() : null;
  let config = settings(extension.config?.values);
  if (!config) return;
  const listeners = new Set();

  // Requests to the browser, and its answers. The browser's binding arrives
  // just after a document's first scripts run, so it's looked up each time,
  // and a request made before then (a document_start script's) waits for it
  // a moment.
  const pending = new Map();
  let lastRequest = 0;
  const binding = async () => {
    for (let waited = 0; typeof globalThis[extension.binding] !== 'function' && waited < 1000; waited += 20) {
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    return globalThis[extension.binding];
  };
  const request = async (message) => {
    const send = await binding();
    if (typeof send !== 'function') throw new Error('No channel to the browser');
    return new Promise((resolve, reject) => {
      const id = ++lastRequest;
      pending.set(id, { resolve, reject });
      send(JSON.stringify({ ...message, id }));
    });
  };
  const hosts = messages(extension.features, request, log);

  let popoutLoaded = false;
  const api = {
    extension: Object.freeze({ id: extension.id, name: extension.name, version: extension.version }),
    config: Object.freeze({
      // The merged settings: a copy each time, so a script can't change
      // another's.
      get: () => structuredClone(config),
      // Called with the new settings after each change; returns a function
      // that stops it.
      onChange: (callback) => {
        listeners.add(callback);
        return () => listeners.delete(callback);
      },
    }),
    feature: hosts.feature,
    // Opens one of the extension's pages in a new tab beside this one.
    openPage: (path) => request({ type: 'openPage', path: String(path).replace(/^\//, '') }),
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
  Object.defineProperty(globalThis, '__openp41geReply', {
    configurable: true,
    value: (id, ok, value) => {
      const request = pending.get(id);
      if (!request) return;
      pending.delete(id);
      if (ok) request.resolve(value);
      else request.reject(new Error(value));
    },
  });
  Object.defineProperty(globalThis, '__openp41geDeliver', { configurable: true, value: hosts.deliver });
  Object.defineProperty(globalThis, '__openp41geSettingsChanged', {
    configurable: true,
    value: (values) => {
      const next = settings(values);
      if (!next) return;
      config = next;
      for (const callback of listeners) {
        try {
          callback(structuredClone(config));
        } catch (error) {
          log('settings change handler failed', error);
        }
      }
    },
  });

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

  // The settings content scripts get from the user's `values` (see the
  // top), or null if they mustn't run.
  function settings(values) {
    if (!settingsLib) return {};
    const { schema } = extension.config;
    const { config, ignored, missing, schemaError } = settingsLib.read(schema, values);
    if (schemaError) {
      log(`not run: its manifest's ${schemaError}`);
      return null;
    }
    if (ignored.length) log(`setting ignored, its default used: ${ignored.join('; ')}`);
    if (missing.length) {
      log(`not run: needs setup (${missing.join('; ')})`);
      return null;
    }
    return settingsLib.withoutSecrets(schema, config);
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
