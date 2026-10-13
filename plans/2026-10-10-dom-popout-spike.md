2026-10-10

**Status: done.** The spike's results are recorded here; element pop-out is in the browser.

# DOM pop-out spike: results

Phase 2 of [PLAN.md](../PLAN.md). The spike (`spikes/dom-popout/`, merged
into `master` and then removed; see its history) proved element pop-out by
**moving the real DOM element** into another window, as part of the same
page. Outcome: **it works**, on YouTube videos and YouTube Shorts, and the
approach moves into the browser itself.

## What was tried

| Approach | Result |
|---|---|
| Pixel mirroring (off-screen page, cropped copy in another window) | Rejected: not the real DOM, and brittle through scrolling and layout changes. Deleted. |
| Alloy pages, element moved into our own child window | Media reloads on the move. Chromium keeps a moved `<video>`'s player only when it moves into a Document Picture-in-Picture window opened by its page (`HTMLMediaElement::ShouldReusePlayer`), and CEF won't support Document PiP for Alloy ([#3448](https://github.com/chromiumembedded/cef/issues/3448)). Workarounds were rejected as tricks. |
| **Chrome-style pages in our own windows, pop-out as Document PiP** | **Works.** Media keeps playing through the move, input is real, and CEF's embedder PiP options make the window ours. |

## How it works

1. A script runs in the page as a user gesture (DevTools `Runtime.evaluate`
   with `userGesture: true`; Document PiP requires one) and calls
   `documentPictureInPicture.requestWindow()`.
2. CEF creates the window **frameless** (`UseFramelessWindowForPictureInPicture`)
   and lets the script **place** it (`AllowMoveForPictureInPicture`): it opens
   over the element and keeps the element's proportions while resized.
3. The script copies the page's stylesheets in and moves the element,
   leaving a placeholder. Same node, listeners and JavaScript context.
4. **Events are forwarded:** events that bubble through the pop-out
   unhandled are re-dispatched on the main document, where pages keep
   document-level listeners (scrubbing drags, press-and-hold). Keys the
   pop-out already handled aren't forwarded, so shortcuts don't run twice.
5. Closing the window moves the element back.
6. Chromium's background throttling is off
   (`disable-background-timer-throttling`, `disable-renderer-backgrounding`,
   `disable-backgrounding-occluded-windows`), so the page keeps full speed
   while hidden.

## Verified

Scripted against a local page with silent media, and against YouTube (muted):

- The element moves in and lays out at the window's size; **media isn't
  reloaded and keeps playing**.
- Real clicks run the page's own handlers; main-document listeners get the
  forwarded events (scrubbing and hold-for-2× work on YouTube).
- Space/K toggle once (not twice); arrow keys seek.
- Minimized or hidden main window: no change.
- **Browsing on:** while popped out, links open as a new page and the
  original page stays alive, so the pop-out keeps playing. New pages' autoplay
  is held (a script injected before the page's own scripts pauses media until
  the user interacts), and a bar offers **Play in pop-out** to swap videos,
  keeping the pop-out's place and width.
- **Frameless controls:** a grab handle and close button, one light/dark
  style, shown on mouse movement.
- **YouTube Shorts:** the Shorts player pops out at 9:16 and keeps playing.
  Previous/next (stacked bottom right), auto-advance (bottom left), a
  seekable progress bar, swipe and arrow keys move the feed with YouTube's
  own navigation. Every change of Short slides, whatever caused it.

## Findings that shape the product

- **One Chrome-style browser view per window:** CEF refuses to *create* a
  second one in a window ("Cannot add multiple Chrome style BrowserViews"),
  so the spike used one window per page. Tabs need a design that fits; next
  step is to check whether a window can swap which view it shows.
- **Pop-out needs a user gesture:** `AllowPictureInPictureWithoutUserActivation`
  had no visible effect; running the script as a DevTools user gesture works.
  Revisit for openp41ge-triggered pop-outs.
- **Moving the feed in the page moves the pop-out:** on Shorts the pop-out
  holds YouTube's only player, so scrolling the original page changes what's
  in the pop-out. Browsing in another tab while the pop-out's page stays in
  the background avoids it.
- **Known risk:** site code that looks the element up in the main document
  (`document.getElementById`) doesn't find it while it's popped out. Not a
  problem on YouTube so far.
- **`--url` can't be our own switch:** Chromium's startup code acts on it.
- Test profiles use `--use-mock-keychain` (no macOS Keychain prompts), and
  test media must be silent.
- Site-specific behaviour (YouTube's inline sizes, Shorts controls) is
  needed, so the product keeps a general core plus **site presets**.
