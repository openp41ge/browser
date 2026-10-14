// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The extension runtime in an extension's own pages
// (openp41ge-extension://<id>/, src/extensions/extension_scheme.h). The
// browser registers it in every page, like the content scripts' runtime
// (runtime.js), but in the page's own world: it does nothing unless the
// page is this extension's. See plans/2026-10-14-extension-system.md,
// "Extension pages".
//
// This file is one function expression. The browser
// (src/extensions/extension_manager.mm) calls it with:
//   extension    { id, name, version, features: [{ id, name, enabled }],
//                pages: [{ path, title, settings }] }
//   config       { schema, values } (the user's values, as stored), or null
//                if the extension has no settings
//   loadSettings returns settings.js's helpers
//   messages     messages.js (feature hosts)
//
// It defines `openp41ge` for the page:
//   extension      { id, name, version }
//   config.get()       the merged settings (with secrets: the page is the
//                      extension's own)
//   config.values()    the user's values, as stored
//   config.schema()    the schema
//   config.problems()  { ignored, missing, schemaError } (see settings.js)
//   config.set(values) replaces the user's values; rejects (and stores
//                      nothing) if they don't fit the schema
//   config.reset(key)  removes the user's value for a top-level setting, so
//                      its default applies again
//   config.onChange(callback) called with the merged settings after every
//                      change, from any of the extension's pages; returns a
//                      function that stops it
//   openPage(path)     opens one of the extension's pages in a new tab
//   feature(id)        the feature's host (messages.js): broadcast to the
//                      feature in tabs and the extension's other pages,
//                      onMessage to answer them
// set, reset, openPage and broadcast return promises. Messages go to the browser over
// `openp41geExtensionQuery`, which only extension pages have
// (renderer_app.cc), and the browser checks which extension's page sent
// them.

(extension, config, loadSettings, messages) => {
  'use strict';

  // Only in this extension's pages, once per document, in the top frame.
  if (location.origin !== `openp41ge-extension://${extension.id}` || window.top !== window) return;
  if (document.openp41geExtensionRan) return;
  document.openp41geExtensionRan = true;

  const schema = config?.schema ?? { type: 'object', properties: {} };
  let values = config?.values ?? {};
  const settings = config ? loadSettings() : null;
  const read = () => (settings ? settings.read(schema, values) : { config: {}, ignored: [], missing: [], schemaError: null });
  let current = read();
  const listeners = new Set();

  const query = (message) =>
    new Promise((resolve, reject) =>
      window.openp41geExtensionQuery({
        request: JSON.stringify(message),
        onSuccess: (response) => resolve(response ? JSON.parse(response) : undefined),
        onFailure: (code, text) => reject(new Error(text)),
      }),
    );

  const hosts = messages(extension.features, query, (message, error) =>
    console.error(`[${extension.name} (${extension.id})] ${message}`, error ?? ''),
  );

  const set = async (next) => {
    const errors = settings ? settings.fits(schema, next) : Object.keys(next ?? {}).length ? ['no settings'] : [];
    if (errors.length) throw new Error(`Settings not saved: ${errors.join('; ')}`);
    await query({ type: 'config.set', values: next });
  };

  const api = {
    extension: Object.freeze({ id: extension.id, name: extension.name, version: extension.version }),
    config: Object.freeze({
      get: () => structuredClone(current.config),
      values: () => structuredClone(values),
      schema: () => structuredClone(schema),
      problems: () => structuredClone({ ignored: current.ignored, missing: current.missing, schemaError: current.schemaError }),
      set,
      reset: (key) => {
        const next = structuredClone(values);
        delete next[key];
        return set(next);
      },
      onChange: (callback) => {
        listeners.add(callback);
        return () => listeners.delete(callback);
      },
    }),
    openPage: (path) => query({ type: 'openPage', path: String(path).replace(/^\//, '') }),
    feature: hosts.feature,
  };
  Object.defineProperty(window, 'openp41ge', { value: Object.freeze(api), configurable: true });

  // The browser calls this with the broadcasts of the extension's content
  // scripts and other pages.
  Object.defineProperty(window, '__openp41geDeliver', { configurable: true, value: hosts.deliver });

  // The browser calls this when the settings change (from any page).
  Object.defineProperty(window, '__openp41geSettingsChanged', {
    configurable: true,
    value: (next) => {
      values = next;
      current = read();
      for (const callback of listeners) {
        try {
          callback(structuredClone(current.config));
        } catch (error) {
          console.error(`[${extension.name} (${extension.id})] settings change handler failed`, error);
        }
      }
    },
  });
}
