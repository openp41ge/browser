2026-10-10 (revised 2026-10-11)

# Element pop-out in the browser

Takes the [DOM pop-out spike](2026-10-10-dom-popout-spike.md) into the
browser itself (`app/`). This is the start of Phase 4 in
[PLAN.md](../PLAN.md); the window model it needs is the start of Phase 3.

**Revision (2026-10-11): the browser provides generic pop-out; site
behaviour lives in the extension.** Browser tests use local pages only and
never depend on YouTube or other live sites. YouTube's player and Shorts
support move to Internet Utility Belt (`packages/web-extension`), which
Chrome-style pages load like any Chrome extension.

## Window model

- Pages are **Chrome-style browser views in our own windows** (CEF Views),
  one page per window for now (see **Tabs**).
- Until our own browser UI exists (Phase 3), each window shows **Chrome's
  toolbar** (back, forward, reload, address bar) so the browser stays usable.
  It's a single setting to switch off once our UI replaces it.
- Requests for new tabs or windows (links, Cmd+T, Cmd+N) open a new page
  window; popups keep their opener.
- Menu commands that Chrome implements (find, zoom, history, downloads, dev
  tools, …) run through CEF's `ExecuteChromeCommand` on the active page.

## In the browser

- **`PopoutController`** (`app/src/popout/`):
  - `PopOut(page, options)`, `Close()`, `Toggle()`, `IsOpen()`, and an
    observer for opened and closed. This is the API the openp41ge link
    (Phase 5) will call. Window → Pop Out Video (Shift+Cmd+P) uses it.
  - Follows **every** Document PiP window, whoever opens it (the browser,
    a page, an extension), so the rest applies to all of them.
  - Every pop-out window is frameless and placeable by its page
    (`PageViewDelegate`'s PiP options).
  - Pages opened while something is popped out hold autoplay: an init
    script passed in the new page's extra info, run by the renderer
    (`renderer_app.cc`) before the page's own scripts.
  - A page that was only kept open for the pop-out closes with it.
- **Page side: `packages/popout`**, shared with the extension. `core.js`
  chooses the element, opens and places the window, moves the element and
  puts it back, adds the frameless controls, forwards events to the page,
  and opens links as new pages (`noopener`) while popped out. It accepts
  site presets but the browser ships none: by default it pops out the
  page's largest visible video.

## In the extension

Internet Utility Belt moves into `packages/web-extension` and builds on
`packages/popout`:

- **YouTube preset:** the player fits the window; theatre and fullscreen
  buttons hidden; a pop-out button on the player (a click gives the page the
  user activation Document PiP needs).
- **Shorts preset:** previous/next, auto-advance, progress bar, swipe and
  arrow keys, sliding between Shorts.
- **Play in pop-out:** offered on a YouTube page while another page's video
  is popped out.
- In stock Chrome the same extension works with Chrome's own PiP window.

## Tests (`browser-tests`)

- `smoke/` (CI): the browser against local fixture pages with **silent**
  media: launch, render, persistence, and pop-out (the move keeps playing,
  input reaches the page, events are forwarded, controls, browsing on keeps
  the pop-out, autoplay is held, closing restores). Also: the browser loads
  an unpacked extension and runs its content scripts.
- `packages/web-extension/`: the extension's own tests, plus live YouTube
  checks that are run by hand, never as a gate on the browser.

## Tabs (next)

A probe: can one window swap which Chrome-style browser view it shows
(created elsewhere, moved in), keeping hidden pages alive? The answer picks
the Phase 3 tabs design: swapping views in one window, or a window per tab
with our own tab strip across them.
