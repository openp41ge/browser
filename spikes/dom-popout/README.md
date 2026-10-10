# DOM pop-out spike (Phase 2)

Proves element pop-out by **moving the real DOM element** into its own
window, as part of the same page, before any browser UI is built.

1. Cmd+Shift+P runs `popout_script.h` in the page. The browser runs it as a
   user gesture (DevTools `Runtime.evaluate` with `userGesture: true`), so
   the popup blocker allows the child window without being disabled for
   websites.
2. The script opens a same-origin child window named
   `openp41ge-popout:x,y,w,h` (the element's rect in the viewport).
3. `SpikeClient::OnBeforePopup` recognises the name and creates the child in
   **our own native window**: floating, placed over the element,
   aspect-locked.
4. The script copies the page's stylesheets into the child document and
   moves the element in, leaving a placeholder. Same node, same listeners,
   same JavaScript context. It lays out at the window's size.
5. **Events are forwarded to the main document.** Events that bubble through
   the pop-out unhandled are re-dispatched on the main document, so the
   page's document-level listeners (drags such as scrubbing, press-and-hold,
   keyboard shortcuts) still see them.
   Keys the pop-out already handled (default prevented) aren't forwarded, so
   shortcuts don't run twice.
6. **Playback continues.** Media that was playing resumes after each move
   (moving between documents pauses it).
7. **Navigating away keeps the pop-out.** While something is popped out,
   links open as a new page in the main window and the original page stays
   alive in the background, so the pop-out keeps playing. If the new page has
   a player, a bar offers **Play in pop-out**: the pop-out switches to the new
   page's player, in the same place and width. Nothing changes until the user
   clicks it.
8. Closing the window (or Cmd+Shift+P again) moves the element back. If its
   page was only kept alive in the background, that page closes too.

The spike has no tabs or address bar: "pages" are browsers stacked in the
main window, only the newest shown.

Chromium's background throttling is switched off
(`disable-background-timer-throttling`, `disable-renderer-backgrounding`,
`disable-backgrounding-occluded-windows`), so the page keeps running at full
speed while its element is elsewhere.

## Build and run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DEXPLORER_BUILD_SPIKES=ON
cmake --build build --target dom_popout_spike
"build/spikes/dom-popout/Release/openp41ge dom popout spike.app/Contents/MacOS/openp41ge dom popout spike"
```

Options: `--start-url=<url>` (default: a 60 fps YouTube video),
`--selector=<css>` (default: `#movie_player`), `--user-data-dir=<dir>`.
(`--url` can't be used: Chromium's startup code cancels Alloy navigations
when that switch is present.)

The spike uses `--use-mock-keychain`, so its throwaway profiles never touch
the macOS Keychain.

## Verified (scripted, on a local test page)

- The child window opens as our window; the element moves into it and lays
  out at the window's size (320×180 window → 320×180 element).
- A real click inside the pop-out runs the page's own handler, in the page's
  original JavaScript context.
- Closing the window moves the element back, with its state intact.
- Clicking a link in the main page while popped out opens a new page; the
  original page stays alive and still owns the pop-out. Closing the pop-out
  then closes the background page and leaves the new one.
- A main-document `mouseup` listener receives the release from a click in
  the pop-out (once, at matching coordinates). Without forwarding, YouTube's
  scrubbing and hold-for-2x never saw the mouse release.
- **Known risk confirmed:** code that looks the element up in the *main*
  document (`document.getElementById`) no longer finds it while popped out.
  Code holding a reference to it keeps working.

## Test on YouTube

1. Play the video, press Cmd+Shift+P. The player moves into a floating
   window over its old spot.
2. Resize the pop-out: the player re-lays out to the new size.
3. Click to pause/play, scrub, open settings, hover for controls, and press
   Space/K/arrow keys. Clicks shouldn't arrive late or be undone, and the
   controls should show and hide normally.
4. Minimize the main window (Cmd+M) or put it behind other windows:
   everything keeps working.
5. Close the pop-out: the player returns and keeps playing.
6. With the player popped out, click another video in the main window: the
   pop-out keeps playing and a bar offers **Play in pop-out**.
