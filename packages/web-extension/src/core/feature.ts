/**
 * A Feature is one self-contained tool on the utility belt.
 *
 * Features are plain DOM code: they must not import extension APIs
 * (`browser.*`, storage, messaging). That keeps them portable to any
 * browser — or even a userscript — while `core/run-feature.ts` handles the
 * extension-specific wiring (settings, lifecycle) and provides the few
 * services that need the extension (FeatureHost).
 */

/** Services a feature gets from wherever it runs. */
export interface FeatureHost {
  /**
   * Sends `message` to this feature in the other tabs where it runs, and
   * resolves with their replies (tabs that don't reply are left out).
   */
  broadcast(message: unknown): Promise<unknown[]>;
  /**
   * Answers messages this feature broadcasts from other tabs: return a
   * reply (or a promise of one), or undefined for no reply. Returns a
   * function that stops listening.
   */
  onMessage(handler: (message: unknown) => unknown): () => void;
}

export interface Feature {
  /** Stable identifier, used as the settings key. Never rename. */
  id: string;
  name: string;
  description: string;
  /** Default on/off state before the user touches the toggle. */
  enabledByDefault?: boolean;
  /**
   * Runtime capability check, evaluated in the page. Return false when the
   * current browser lacks the APIs this feature needs.
   */
  isSupported?: () => boolean;
  /** Install the feature on the page. Returns a teardown function. */
  setup: (host: FeatureHost) => () => void;
}

export function defineFeature(feature: Feature): Feature {
  return feature;
}
