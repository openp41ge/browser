import { browser } from 'wxt/browser';
import type { ContentScriptContext } from 'wxt/utils/content-script-context';
import type { Feature, FeatureHost } from './feature';
import { type BroadcastRequest, isDelivery } from './messages';
import { featureEnabledItem } from './settings';

/** FeatureHost for a content script: other tabs are reached through the background script. */
function contentScriptHost(feature: Feature): FeatureHost {
  return {
    async broadcast(message) {
      const request: BroadcastRequest = { kind: 'utility-belt:broadcast', featureId: feature.id, message };
      try {
        const replies = await browser.runtime.sendMessage(request);
        return Array.isArray(replies) ? replies : [];
      } catch {
        // The extension was reloaded or removed while this page stayed open
        // ("Extension context invalidated"): there's no one left to ask.
        return [];
      }
    },
    onMessage(handler) {
      const listener = (message: unknown, _sender: unknown, sendResponse: (reply: unknown) => void) => {
        if (!isDelivery(message) || message.featureId !== feature.id) return;
        Promise.resolve(handler(message.message)).then(
          (reply) => sendResponse(reply),
          () => sendResponse(undefined),
        );
        return true; // Replies asynchronously.
      };
      browser.runtime.onMessage.addListener(listener);
      return () => browser.runtime.onMessage.removeListener(listener);
    },
  };
}

/**
 * Runs a feature inside a content script: respects the user's toggle (live,
 * without a page reload) and tears down when the extension is reloaded or
 * disabled.
 */
export function runFeature(feature: Feature, ctx: ContentScriptContext): void {
  if (feature.isSupported && !feature.isSupported()) return;

  const host = contentScriptHost(feature);
  let teardown: (() => void) | undefined;
  const apply = (enabled: boolean) => {
    if (enabled && !teardown) {
      teardown = feature.setup(host);
    } else if (!enabled && teardown) {
      teardown();
      teardown = undefined;
    }
  };

  const enabled = featureEnabledItem(feature);
  enabled.getValue().then(apply);
  const unwatch = enabled.watch(apply);

  ctx.onInvalidated(() => {
    unwatch();
    teardown?.();
  });
}
