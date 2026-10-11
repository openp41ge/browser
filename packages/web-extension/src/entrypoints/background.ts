import { browser } from 'wxt/browser';
import { type Delivery, isBroadcastRequest } from '@/core/messages';

/**
 * Carries FeatureHost.broadcast() between tabs: delivers a feature's message
 * to that feature in every other tab and collects the replies.
 */
export default defineBackground(() => {
  browser.runtime.onMessage.addListener((message: unknown, sender, sendResponse: (replies: unknown[]) => void) => {
    if (!isBroadcastRequest(message)) return;
    const delivery: Delivery = { kind: 'utility-belt:deliver', featureId: message.featureId, message: message.message };
    browser.tabs.query({}).then(async (tabs) => {
      const replies = await Promise.all(
        tabs
          .filter((tab) => tab.id !== undefined && tab.id !== sender.tab?.id)
          // Tabs without the feature's content script reject: no reply.
          .map((tab) => browser.tabs.sendMessage(tab.id!, delivery).catch(() => undefined)),
      );
      sendResponse(replies.filter((reply) => reply !== undefined && reply !== null));
    });
    return true; // Replies asynchronously.
  });
});
