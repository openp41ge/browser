2026-10-10

# Element pop-out in the browser

Takes the [DOM pop-out spike](2026-10-10-dom-popout-spike.md) into the
browser itself (`app/`). This is the start of Phase 4 in
[PLAN.md](../PLAN.md); the window model it needs is the start of Phase 3.

## Window model

- Pages are **Chrome-style browser views in our own windows** (CEF Views),
  one page per window for now (see **Tabs**).
- Until our own browser UI exists (Phase 3), each window shows **Chrome's
  toolbar** (back, forward, reload, address bar) so the browser stays usable.
  It's a single setting to switch off once our UI replaces it.
- Requests for new tabs or windows (links, Cmd+T, Cmd+N) open a new page
  window.
- Menu commands that Chrome implements (find, zoom, history, downloads, dev
  tools, …) run through CEF's `ExecuteChromeCommand` on the active page.

## Pop-out module (`app/src/popout/`)

- **Native side:** `PopoutController`, one per app:
  - `PopOut(page, options)`, `Close()`, `IsOpen()`, and an observer for opened
    and closed. This is the API the openp41ge link (Phase 5) will call.
  - Makes Document PiP windows frameless and placeable.
  - Holds autoplay in pages opened while something is popped out.
  - Offers **Play in pop-out** on pages with a player, and swaps in place.
  - Closes a page that was only kept open for the pop-out once it closes.
- **Page side:** scripts in the app bundle (`Resources/popout/`), not
  C++ strings:
  - `core.js`: element choice, the window, moving the element and putting
    it back, the frameless controls, event forwarding, links opening as new
    pages. Works on any site.
  - `presets/*.js`: site presets that add to the core. Each preset matches
    a site and/or element and can add CSS and controls. First presets:
    `youtube.js` (player fit, hidden theatre/fullscreen buttons) and
    `youtube-shorts.js` (feed controls, sliding, progress bar).
  - `hold-autoplay.js`: the autoplay hold for new pages.
- **What gets popped out:** an explicit selector if given (tests,
  openp41ge), else the matching preset's element, else the page's largest
  visible video (preferring a playing one).

## Tests (`browser-tests`)

- `smoke/popout.mjs` drives the built app against local fixture pages with
  **silent** media: the move keeps playing, input reaches the page, events
  are forwarded, browsing on keeps the pop-out, autoplay is held, close
  restores. Runs in CI with the smoke tests.
- `live/youtube.mjs`: the YouTube video and Shorts checks. Run by hand,
  since YouTube changes underneath them.

## Tabs (next)

A probe: can one window swap which Chrome-style browser view it shows
(created elsewhere, moved in), keeping hidden pages alive? The answer picks
the Phase 3 tabs design: swapping views in one window, or a window per tab
with our own tab strip across them.
