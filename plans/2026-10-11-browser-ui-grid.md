2026-10-11

# Browser UI: top bar, pane grid and tabs (Alloy)

The browser's own UI, starting Phase 3 of [PLAN.md](../PLAN.md): a window
that looks like the openp41ge app, with a top bar, a grid of panes, and a tab
bar per pane whose tabs are web pages. Dragging a tab to a pane's edge splits
the grid.

## Decision: pages are Alloy style

Chrome-style pages can't do this with CEF's prebuilt binaries:

- A window holds **one** Chrome-style page (CEF refuses a second).
- Moving a Chrome-style page into another window, side by side or one at a
  time, **crashes** (probe, 2026-10-11).

Alloy-style pages can (probes, 2026-10-11, prebuilt CEF 154):

| | Result |
|---|---|
| Several pages side by side in one window | Works |
| Take a page out of its pane (kept alive), put another in, swap back | Works |
| Move a page from another window into the grid | Works |
| Document Picture-in-Picture in an Alloy page | `requestWindow()` works and reaches `OnBeforePopup` as a PiP request |
| Media moved into it | **Keeps playing** (no reload): Chromium's `ShouldReusePlayer` holds |
| PiP window in our own frameless `NSWindow` (`SetAsChild`) | Works, at the size the page asked for |
| Page script `moveTo()` / `resizeTo()` on it | Ignored / refused: the browser places and sizes the window itself |

So: **every page is an Alloy-style browser view, and Chrome style is
dropped entirely** (decided 2026-10-11). A CEF source build isn't needed.
What Alloy pages don't get, compared with Chrome style:

- **Chrome extensions.** Our own features are injected by the browser
  instead (see **Features**).
- **Chrome's UI:** settings, history, downloads, password manager,
  permission prompts, find bar, and Google features (wanted off anyway). We
  provide what we need (see **Alloy gaps**).

## Window structure

```
┌──────────────────────────────────────────────────────────────┐
│ ● ● ●   ‹ ›  ⟳                       top bar (35px)          │
├────────────────────┬─────────────────────────────────────────┤
│ Tab A │ Tab B │  + │ Tab C │                              +  │  tab bar per pane (35px)
├────────────────────┼─────────────────────────────────────────┤
│                    │                                         │
│   page (Tab A)     │   page (Tab C)                          │  pages: Alloy browser views
│                    │                                         │
└────────────────────┴─────────────────────────────────────────┘
```

- **Frameless window** with macOS's traffic lights in the top bar (done:
  `PageWindow`, `IsFrameless` + `WithStandardWindowButtons` +
  `GetTitlebarHeight`).
- **One UI view per window, the "frame":** an Alloy browser view running our
  HTML/CSS/JS (openp41ge://ui/, as the top bar does now) that fills the
  window and draws the top bar, every tab bar, the splitters and the drag
  previews. It lays the grid out with CSS and reports each pane's page area
  to the shell.
- **Pages are overlay views** on top of the frame (`CefWindow::AddOverlayView`,
  custom docking), placed at the page areas the frame reports. A pane shows
  its active tab's page; other tabs' pages are taken out of the window and
  kept alive (probe: works).
- **Drag previews over pages** (drop rings and washes) can't be drawn by the
  frame, which sits under the pages. They're native overlay panels
  (`CefPanel` with translucent background colours) placed from the frame's
  layout during a drag.

Why one frame view rather than a view per tab bar: one place to lay out the
grid, run drags (mouse capture stays with the view the drag started in, even
over pages), animate and theme; the shell only places rectangles.

## Grid model (matches openp41ge)

The grid is **one row of columns**, split left/right only, like openp41ge's
(`openp41ge-sdk-uikit` `tab-grid`, `openp41ge-core-tabs`). There will never
be top/bottom splits (decided 2026-10-11), so the model is just a list of
columns.

- **Columns:** each has tabs (in order), an active tab and a width. Widths
  are shared (`flex: 1`) until a splitter is dragged.
- **Minimum column width** 200px; a column is at most 50% of the window
  while being resized.
- **Splitters:** a 5px handle straddling the column border (no layout
  space), `col-resize`; a 3px blue line (`rgb(74,158,255)`) fades in on hover
  or drag. Dragging past the limits is damped and springs back. Double-click
  makes all columns equal.
- **Last tab moved out of a column:** the column is removed and its width
  shared out.

Persisted per window (and per session): columns, their tabs (URL, title)
and widths.

## Tab bar (matches openp41ge's `tab-bar`)

- 35px, `--bg-surface` background, 1px `--border-divider` bottom border,
  horizontal scrolling with the scrollbar hidden and edge fades.
- Tabs: min 120px, 12px text, `border-right: 1px solid #333`. Active tab
  `background: var(--border-divider)`, text `#eee`; inactive `#888`. A
  34×34 ✕ close button. Long titles scroll on hover.
- A `+` at the right opens a new tab in that pane.
- Favicon and loading state on each tab (browser addition).

## Dragging tabs (matches openp41ge's `core-tabs`)

- A drag starts once the mouse has moved 3px with the button down; the
  cursor is `grabbing`; the source tab dims to 40%.
- **Drop targets:**
  - near a column edge (15% of the grid width, at most 1/3 of the narrower
    neighbour): **split** there, new column at the midpoint;
  - in a tab bar: **reorder** (or move into that pane) at the insertion
    point, shown by a 3px blue line with a glow;
  - elsewhere in a column: **move** into that pane.
- **Preview:** the resulting layout drawn over the grid: the landing area
  gets a 3px blue ring with a glow and `rgba(74,158,255,.2)` wash, the rest
  a faint wash.
- **Out of the window:** dropping outside opens the tab in a new window at
  the drop point; dropping onto another window's grid moves it there
  (pages can move between windows: probe).

## Pop-out (element pop-out in Alloy)

- The page's Document PiP request arrives in `OnBeforePopup` (disposition
  `CEF_WOD_NEW_PICTURE_IN_PICTURE`); the browser creates **its own
  frameless, floating `NSWindow`** and has CEF create the PiP page inside it
  (`CefWindowInfo::SetAsChild`).
- The **browser** places it over the element (it asks the page for the
  element's position), keeps it at the element's shape
  (`NSWindow.contentAspectRatio`) and reshapes it when told to (e.g. Shorts).
  The page-side code (`packages/popout`) stops calling `moveTo`/`resizeTo`
  in our browser and asks the browser instead.
- Dragging by our handle: the PiP page's `-webkit-app-region: drag` areas
  (`CefDragHandler::OnDraggableRegionsChanged`) move the window.
- Autoplay hold for new pages and closing a page kept open only for the
  pop-out carry over from `PopoutController`.

## Features (Internet Utility Belt in Alloy pages)

Alloy pages don't load Chrome extensions, so the browser runs the
extension's features itself, as the plan originally intended (Phase 6):

- The features are plain DOM code with host services passed in
  (`FeatureHost`, settings). A **CEF host** provides those: cross-tab
  messages through the browser process, settings in the profile.
- Scripts are injected by the renderer (`OnContextCreated`) into matching
  pages. They run in the page's own JavaScript world (CEF doesn't expose
  isolated worlds), so the host channel they use must only accept what a
  feature may do, and nothing that reaches the browser's UI channel.
- The extension itself stays, for Chrome, Edge and Brave.

## Alloy gaps to fill (as needed)

Chrome style gave us these; with Alloy pages we provide them:

| Need | How |
|---|---|
| Find in page | `CefBrowserHost::Find`, a small find bar in the frame |
| Permission prompts (camera, mic, location, notifications) | `CefPermissionHandler`, a prompt in the frame |
| Downloads | `CefDownloadHandler`, a downloads list |
| HTTP auth, certificate errors | `CefRequestHandler`, prompts / error pages |
| Context menu | CEF's default for now; ours later |
| Zoom, print, dev tools | `CefBrowserHost` (`SetZoomLevel`, `Print`, `ShowDevTools`) |
| New tab page | Ours (openp41ge://ui/newtab) |
| Address entry | The command palette (see below) |

## Command palette

Typing an address or a search happens in a command palette over the grid
(decided 2026-10-11), not in a toolbar:

- **Cmd+L** opens it for the focused tab: Return loads the address, or
  searches for anything that isn't one, in that tab.
- **Cmd+T** opens it for a new tab in the focused pane.
- It's drawn by the frame view, centred near the top, in openp41ge's style.
  Later it can list open tabs, history and commands.

## Steps

1. **Alloy pages + frame view:** windows become a frame UI view with pages
   as overlay views; one pane, tabs (open, switch, close, reorder), Cmd+T /
   Cmd+W / Cmd+Shift+[ ]; the command palette (Cmd+L, Cmd+T). The current
   top bar moves into the frame. Chrome-style code goes.
2. **Grid:** splitting by dragging tabs, splitters, removing empty columns,
   drop previews; persistence.
3. **Pop-out in Alloy:** our own PiP window, placed and shaped by the
   browser; drag handle; carry over the autoplay hold.
4. **Features in Alloy pages:** the CEF host for Internet Utility Belt; the
   YouTube and Shorts features run in the browser without the extension.
5. **Between windows:** drag tabs to other windows and out to new ones.
6. **Alloy gaps** from the table, in order of need.

Each step comes with smoke tests on local fixture pages (no live sites), run
in CI rather than on a developer's screen.

## To check early (risks)

- **Pages as overlay views:** that `AddOverlayView` takes Alloy browser
  views, layers them over the frame view, and handles input and focus
  normally. Fallback: lay pages out with CEF's box layouts (the frame then
  becomes several views: top bar, one per tab bar).
- **Hidden pages:** that pages taken out of the window keep running and
  repaint when shown again (the probe showed them alive and resized, but
  not repainting on screen).
- **Translucent native overlays** for drag previews (`CefPanel` background
  alpha over browser views).
- **Pop-out placement:** where the PiP window's content view sits relative
  to `SetAsChild` bounds, and keyboard focus in it.

## Decided

1. Splits are left/right only; never top/bottom.
2. Chrome-style pages and windows are dropped entirely.
3. Addresses are typed in a command palette (Cmd+L, Cmd+T).
