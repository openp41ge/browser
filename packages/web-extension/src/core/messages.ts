/**
 * Messages between content scripts and the background script that carry
 * FeatureHost.broadcast() between tabs.
 */

/** Content script -> background: deliver to this feature in the other tabs. */
export interface BroadcastRequest {
  kind: 'utility-belt:broadcast';
  featureId: string;
  message: unknown;
}

/** Background -> content script: a broadcast from another tab. */
export interface Delivery {
  kind: 'utility-belt:deliver';
  featureId: string;
  message: unknown;
}

export function isBroadcastRequest(value: unknown): value is BroadcastRequest {
  return (value as BroadcastRequest | null)?.kind === 'utility-belt:broadcast';
}

export function isDelivery(value: unknown): value is Delivery {
  return (value as Delivery | null)?.kind === 'utility-belt:deliver';
}
