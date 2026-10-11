# Internet Utility Belt

Small quality-of-life tools for the web, packaged as a cross-browser extension
(Chrome/Edge/Brave via MV3, Firefox, Safari) using [WXT](https://wxt.dev).

## Develop

```sh
npm install
npm run dev            # launches Chrome with the extension, hot-reloads
npm run dev:firefox
npm run build          # -> .output/chrome-mv3 (load unpacked in chrome://extensions)
npm run build:firefox
```

## Layout

```
src/
  core/          extension glue: Feature type, settings, lifecycle (runFeature), FeatureHost
  lib/           reusable, browser-agnostic DOM helpers (element pop-out…)
  features/      one folder per feature; plain DOM code, no extension APIs
    index.ts     registry — the popup builds its toggles from this
  entrypoints/   WXT entrypoints: content scripts (thin), background, popup
```

Features never import `browser.*`. They export a `defineFeature({ id, name,
description, isSupported?, setup })` object whose `setup(host)` returns a
teardown. `runFeature()` wires it to the user's on/off toggle and the content
script lifecycle, and passes a `FeatureHost` for the few things that need the
extension (talking to the same feature in other tabs, relayed by the
background script). Keeping features as pure DOM code means they work in any
browser that has the needed web APIs.

Element pop-out comes from [`@openp41ge/popout`](../popout) (shared with
openp41ge explorer); `src/lib/popout.ts` wraps it.

## Adding a feature

1. `src/features/<name>/index.ts` — `export const myFeature = defineFeature({...})`
2. Add it to `src/features/index.ts`.
3. Run it from a content script: either add `runFeature(myFeature, ctx)` to an
   existing entrypoint with the same `matches`, or create
   `src/entrypoints/<site>.content.ts`.

## Features

### Pop out YouTube videos

A button at the top centre of the YouTube player (shown on hover; on Shorts,
an icon among YouTube's own controls, beside "More actions") pops the
whole player, with YouTube's own controls, captions and settings, out into
its own window: the real player, still part of the page, so it keeps
playing.

- **In openp41ge explorer** the window is frameless and opens right over the
  player; drag it by the handle at the top, close it with the button
  top-right (both show on mouse movement).
- **Shorts** get previous/next (bottom right), auto-advance (bottom left), a
  seekable progress bar, swipe and arrow keys, and slide between Shorts.
- **Play in pop-out:** while a video is popped out, the button on other
  YouTube tabs turns blue and offers to play their video there instead (same
  place and size).
- **Other Chromium browsers** use their own Document Picture-in-Picture
  window. **Safari** falls back to standard PiP of the bare video.
  **Firefox** has no PiP web API; the feature disables itself.

Live checks against youtube.com, in openp41ge explorer, are in the private
tests repo (`packages/web-extension/live-youtube.mjs`), run by hand.
