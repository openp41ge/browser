import { storage } from 'wxt/utils/storage';
import type { Feature } from './feature';

/** Synced on/off toggle for a feature. */
export function featureEnabledItem(feature: Feature) {
  return storage.defineItem<boolean>(`sync:feature:${feature.id}:enabled`, {
    fallback: feature.enabledByDefault ?? true,
  });
}
