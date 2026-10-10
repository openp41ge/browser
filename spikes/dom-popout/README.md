# DOM pop-out spike (Phase 2)

Proves element pop-out by **moving the real DOM element** into its own
window, as part of the same page, before any browser UI is built.

Pages are **Chrome-style browser views in our own windows** (CEF Views,
Chrome's toolbar off). The pop-out is a **Document Picture-in-Picture**
window: the web's API for moving live elements into another window.
Chromium keeps media playing across that move. It reloads media moved into
any other kind of window, which is why Alloy-style pages (no Document PiP in
CEF) couldn't do this.

1. Cmd+Shift+P runs `popout_script.h` in the page, as a user gesture
   (DevTools `Runtime.evaluate` with `userGesture: true`; Document PiP
   requires one).
2. The script calls `documentPictureInPicture.requestWindow()`. CEF creates
   it **frameless** (`UseFramelessWindowForPictureInPicture`), and the script
   moves it over the element and keeps it at the element's proportions
   (`AllowMoveForPictureInPicture`).
3. The script copies the page's stylesheets in and moves the element,
   leaving a placeholder. Same node, listeners, JavaScript context, and
   media keeps playing.
4. **Events are forwarded to the main document.** Events that bubble through
   the pop-out unhandled are re-dispatched on the main document, so the
   page's document-level listeners (drags such as scrubbing, press-and-hold)
   still see them. Keys the pop-out already handled aren't forwarded, so
   shortcuts don't run twice.
5. **Frameless window controls:** a grab handle centred at the top drags the
   window, and a close button sits top-right. They show on any mouse movement
   and hide after 2.5 s idle. Over the handle the page gets no mouse events
   (the OS treats drag regions as window frame), so they stay up while the
   pointer was last seen at the handle. Both share one style that follows the
   system's light/dark setting (`prefers-color-scheme`). The handle is compact because drag
   regions take clicks even when hidden; centred, it stays clear of controls
   like YouTube's title and top buttons.
6. **Browsing on keeps the pop-out.** While something is popped out, links
   open in a new page window and the original page stays open, so the pop-out
   keeps playing. New pages' autoplay is held (a script injected before the
   page's own scripts pauses media until the user interacts). If the new page
   has a player, a bar offers **Play in pop-out**: the pop-out switches to it,
   in the same place and width.
7. **YouTube Shorts:** the pop-out holds YouTube's single Shorts player, so
   it can move the feed. Previous sits above next at the bottom right,
   auto-advance at the bottom left, and a progress bar runs along the bottom
   edge:
   - previous/next, the up/down arrow keys (in the pop-out or the page) and
     a vertical swipe (one Short per gesture) press YouTube's own navigation
     buttons (`#navigation-button-up/down`);
   - every change of Short slides, whatever caused it (our controls, keys,
     YouTube's own auto-scroll): the pop-out keeps the last frame shown, and
     when the page swaps the video's source that frame slides away as the
     next Short slides in. Going back to a Short seen earlier slides down,
     anything else slides up, like the Shorts feed;
   - auto-advance moves on when a Short finishes (Shorts loop, so "finished"
     is the position wrapping back to the start);
   - the progress bar is always shown, thickens under the pointer, and seeks
     on click or drag (its events aren't forwarded to the page).
8. Closing the pop-out moves the element back. If its page was only kept open
   for the pop-out, that page window closes too.

Chromium's background throttling is switched off
(`disable-background-timer-throttling`, `disable-renderer-backgrounding`,
`disable-backgrounding-occluded-windows`).

**CEF constraint found:** only one Chrome-style browser view can be *created*
in a window, so each page gets its own window here. Tabs in the real browser
need a design that fits this.

## Build and run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DEXPLORER_BUILD_SPIKES=ON
cmake --build build --target dom_popout_spike
"build/spikes/dom-popout/Release/openp41ge dom popout spike.app/Contents/MacOS/openp41ge dom popout spike"
```

Options: `--start-url=<url>` (default: a 60 fps YouTube video),
`--selector=<css>` (default: `.html5-video-player`, YouTube's regular and
Shorts players), `--user-data-dir=<dir>`. When several elements match, the
pop-out takes a visible one, preferring the one whose video is playing, then
the largest (a Shorts page also has a hidden 0×0 regular player).
(`--url` can't be used: Chromium's startup code acts on that switch.)

The spike uses `--use-mock-keychain`, so its throwaway profiles never touch
the macOS Keychain.

## Verified (scripted, on a local test page with playing audio)

- The pop-out opens as a frameless Document PiP window; the element moves in
  and lays out at its size.
- **Media isn't reloaded by the move and keeps playing** (time carried on
  from 1.40 s to 2.26 s).
- A real click in the pop-out runs the page's own handler; a main-document
  `mouseup` listener receives the release.
- A link opens a new page window while the original page and pop-out keep
  running; the new page's autoplay is held.
- Closing the pop-out returns the element and closes the background page.
- **YouTube Shorts** (automated, muted): the Shorts player pops out at its
  9:16 shape and keeps playing with no reload (5.1 s → 8.6 s on a 24.7 s
  Short, no `emptied`/`seeking` events). Scrolling the *main* window to the
  next Short loads it into the same player, which is in the pop-out, so the
  pop-out switches Shorts. Expected to be resolved by the tabs UI (browsing
  happens in another tab while the pop-out's page stays in the background).
- **Shorts controls** (automated, muted, real clicks/wheel in the pop-out):
  previous above next at the bottom right, auto-advance bottom left,
  progress bar along the bottom edge; next, one-swipe-one-Short, previous
  back to the same Short, and auto-advance at the end all moved the feed,
  slid, and kept playing. Arrow down in the pop-out, arrow up in the page
  and a move made by YouTube itself also slid, each in the right direction. The progress bar tracked playback, and a drag from
  25% to 75% seeked to 75% on the same Short, still playing.
- **Known risk:** code that looks the element up in the *main* document
  (`document.getElementById`) doesn't find it while popped out.

## Test on YouTube

1. Play the video, press Cmd+Shift+P. The player moves into a frameless
   window over its old spot **and keeps playing**.
2. Drag it by the handle at the top; resize it (it keeps the player's shape).
3. Click to pause/play, scrub, settings, hover controls, Space/K/arrows.
4. Minimize the main window or put it behind others: everything keeps working.
5. Click another video: it opens in a new window without playing, and a bar
   offers **Play in pop-out**. Try it.
6. Close the pop-out (× on hover): the player returns and keeps playing.
