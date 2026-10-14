// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Feature hosts, for the extension runtime in content scripts (runtime.js)
// and in the extension's own pages (page-runtime.js): an extension's
// features talk to themselves in other tabs and to its pages, through the
// browser, which delivers messages only within the extension. Matches the
// FeatureHost of Internet Utility Belt (retired; its YouTube pop-out is
// now openp41ge/browser-community's extensions/youtube-popout). See
// plans/2026-10-14-extension-system.md, "What content scripts get".
//
// This file is one function expression. Each runtime calls it with:
//   features  [{ id, name, enabled }]: the manifest's, as the user set them
//   request   (message) => Promise: sends { type, … } to the browser and
//             resolves with its answer (rejects with its refusal)
//   log       (message, error) => void
// and gets { feature(id), deliver(featureId, message) }:
//   feature(id).id, .name, .enabled
//   feature(id).broadcast(message) sends `message` (JSON) to the feature
//     in the extension's other tabs and pages, and resolves with their
//     replies (one per handler that returned something; a handler that
//     takes more than 5 s is left out)
//   feature(id).onMessage(handler) answers them: `handler(message)` returns
//     a reply (or a promise of one), or undefined for none; returns a
//     function that stops it
//   deliver(featureId, message) is what the browser calls with another
//     tab's or page's broadcast: the replies of this document's handlers

(features, request, log) => {
  'use strict';

  const REPLY_TIMEOUT_MS = 5000;
  const handlers = new Map(); // By feature id.

  const json = (value) => {
    const text = JSON.stringify(value);
    if (text === undefined) throw new TypeError('A message must be JSON');
    return JSON.parse(text);
  };

  const feature = (id) => {
    const info = features.find((f) => f.id === id);
    if (!info) throw new Error(`No feature "${id}" in the extension's manifest`);
    return Object.freeze({
      id: info.id,
      name: info.name,
      enabled: info.enabled,
      broadcast: async (message) => request({ type: 'broadcast', feature: id, message: json(message) }),
      onMessage: (handler) => {
        if (!handlers.has(id)) handlers.set(id, new Set());
        handlers.get(id).add(handler);
        return () => handlers.get(id).delete(handler);
      },
    });
  };

  const deliver = async (id, message) => {
    const set = handlers.get(id);
    if (!set?.size) return [];
    const timeout = () => new Promise((resolve) => setTimeout(() => resolve(undefined), REPLY_TIMEOUT_MS));
    const replies = await Promise.all(
      [...set].map((handler) =>
        Promise.race([Promise.resolve().then(() => handler(structuredClone(message))), timeout()]).then(
          (reply) => (reply === undefined ? undefined : json(reply)),
          (error) => {
            log(`feature "${id}": a message handler failed`, error);
            return undefined;
          },
        ),
      ),
    );
    return replies.filter((reply) => reply !== undefined);
  };

  return Object.freeze({ feature, deliver });
}
