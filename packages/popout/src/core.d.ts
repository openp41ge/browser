// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Types for core.js, which defines `globalThis.__openp41ge` when run.

export {};

declare global {
  // eslint-disable-next-line no-var
  var __openp41ge: Openp41gePopout.Api;

  namespace Openp41gePopout {
    /** [screenX, screenY, width] of a pop-out window. */
    type Place = [number, number, number];

    type Outcome = 'opened' | 'already-open' | 'nothing-to-pop-out' | 'refused';

    interface Options {
      /** The element to pop out. */
      element?: Element | null;
      /** Or a CSS selector for it (default: a site preset's, else the largest visible video). */
      selector?: string;
      /** Start the element's media after the move. */
      play?: boolean;
      /** Where to open (default: right over the element). */
      place?: Place | null;
    }

    interface PresetContext {
      el: Element;
      win: Window;
      doc: Document;
      /** An SVG icon; stroked on a 10x10 grid unless `filled`. */
      icon(d: string, options?: { viewBox?: string; filled?: boolean }): SVGSVGElement;
      /** A button in the pop-out's control style, shown and hidden with the others. */
      control(options: {
        className?: string;
        label: string;
        icon: SVGSVGElement;
        onClick: (event: MouseEvent) => void;
        parent?: Element;
      }): HTMLButtonElement;
      /** Keeps a control's own input in the pop-out instead of forwarding it to the page. */
      keepEventsHere(node: Element): void;
    }

    interface Preset {
      id: string;
      /** location.hostname the preset is for. */
      hosts: RegExp;
      /** The site's element to pop out when none is given. */
      selector?: string;
      /** Narrows which popped-out elements the preset handles. */
      appliesTo?: (el: Element) => boolean;
      /** Extra CSS for the pop-out window. */
      css?: string;
      /** Starts the element's media the site's way (for the `play` option). */
      play?: (el: Element) => void;
      /** Adds behaviour once the element has moved in; may return a teardown. */
      setup?: (ctx: PresetContext) => void | (() => void);
    }

    interface Api {
      popout(options?: Options): Promise<Outcome>;
      definePreset(preset: Preset): void;
      /** Whether the page has something to pop out by the default choice. */
      hasPopoutTarget(selector?: string): boolean;
      /** Where the open pop-out is, or null. */
      popoutPlace(): Place | null;
      /** The open pop-out, if any. */
      current: { win: Window } | null;
    }
  }
}
