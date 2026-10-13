2026-10-10

# openp41ge explorer

## Goal

An open-source web browser **built on CEF (the Chromium Embedded Framework)**,
released alongside Openp41ge and integrated with it. Its headline capability
is **element pop-out**: any part of a web page (a video player, a chat, a
dashboard widget) moves into its own native window **as real DOM**. The
element stays part of the same page: the same JavaScript context, event
listeners and state. Clicks, keys and scrolling in that window are ordinary
input to the element, and it lays out at the window's size. Closing the
window puts the element back.

That gives Picture-in-Picture for any site (opening over the element, always
on top, dragged from anywhere, locked to the element's aspect ratio), and more
generally lets you pin arbitrary pieces of websites onto the desktop or into
an Openp41ge pane.

The Openp41ge app (`openp41ge/app`) **stays on Electron**. The browser and the
app are separate programs that talk over a defined, versioned link.

This repo is also the new home of **Internet Utility Belt**, the cross-browser
web extension (currently `~/Repository/internet-utility-belt`).

## Decisions

| Decision | Choice |
|---|---|
| Name | **openp41ge explorer**: bundle id `com.openp41ge.explorer` (matches the app's `com.openp41ge.app`) |
| Engine | CEF binary distributions (no Electron, no Chromium fork) |
| Browser style | **Alloy-style pages in our own windows** (decided 2026-10-11): our own UI (top bar, pane grid, tabs, start page); no Chrome UI, no Google features. Chrome style was used during the spike and dropped: one Chrome-style page per window, and pages can't move between windows. See [plans/2026-10-11-browser-ui-grid.md](plans/2026-10-11-browser-ui-grid.md) |
| Element pop-out | The **real DOM element moves** into a **Document Picture-in-Picture** window (`documentPictureInPicture.requestWindow()`), which the browser hosts in its own frameless window. Media keeps playing (also in Alloy pages: probe 2026-10-11). Pixel mirroring was tried and rejected |
| Shell language | C++ (CEF's first-class API) |
| Video codecs | Ship v1 **without** proprietary codecs (H.264/AAC); standard CEF binaries |
| Platforms | macOS (12+), Apple Silicon and Intel: releases are universal; others later |
| Source hosting | [`openp41ge/browser`](https://github.com/openp41ge/browser) (**public**) |
| Tests | [`openp41ge/browser-tests`](https://github.com/openp41ge/browser-tests) (**private**); see **Tests** |
| CI and releases | GitHub Actions and **GitHub Releases** from day one; see **GitHub, CI and releases** |
| Default branch | `master` (matches `openp41ge/app`) |

## Rationale

The web extension hit hard limits trying to build "PiP of YouTube's player":

- Chrome's PiP windows can't be positioned, dragged by their content, or locked
  to an aspect ratio by an extension.
- Moving YouTube's real player into a Document PiP window works visually, but
  YouTube's code still schedules its work from the original tab. Clicks fired
  late, controls stalled on hover, and playback state fought with our own
  handling.

Moving the real element into another window is the right model; the problems
were Chrome's limits around it:

- Chrome decides where PiP windows go and how they behave.
- Chrome slows down ("throttles") the original tab once its content leaves it.

Owning the browser removes both: we create the element's window ourselves,
and throttling is ours to switch off.

A pixel-mirroring approach (render the page off-screen and show a cropped
copy elsewhere) was prototyped and **rejected (2026-10-10)**. It isn't the
real DOM, and keeping the copy aligned through scrolling and layout changes
proved brittle.

**Why CEF:**

- **No Electron** (ruled out for the browser).
- **No fork:** CEF ships **prebuilt Chromium binaries** for every Chrome
  release, so there's no 100 GB checkout, no multi-hour builds, and no patch
  series to carry.
- **Its public API has what element pop-out needs:** control over how popup
  windows are created (`OnBeforePopup`), so a page's child window can be our
  own native window; command-line control of Chromium's throttling; and
  script injection and DevTools protocol access.
- **Escape hatch:** if a must-have feature needs changes inside Chromium,
  CEF can be built from source with our patches. That's only adopted behind an explicit gate
  (Phase 7).

## Key CEF facts this plan depends on

As of CEF M128+ (see [CEF issue #3685](https://github.com/chromiumembedded/cef/issues/3685)):

- CEF runs on the **Chrome bootstrap** and can create two browser styles:
  - **Chrome style:** Chrome's UI and behaviour, including **Chrome extension
    support**.
  - **Alloy style:** minimal: no Chrome UI or Google features; the
    embedder provides the browser UI. **No Chrome extension support** (the
    Alloy extension API was removed in M128).
- Release branches track Chromium milestones. Within a branch the CEF API is
  frozen and only security/bug fixes land, published as automated binary
  builds at [cef-builds.spotifycdn.com](https://cef-builds.spotifycdn.com/index.html).
- Standard binary builds **exclude proprietary codecs** (H.264/AAC). Enabling
  them requires building CEF from source.

**Decision (2026-10-11): Alloy-style pages in our own windows.** Every page
is an Alloy-style `CefBrowserView`; the browser draws all of its UI itself
(top bar, pane grid, tabs, start page). No Chrome UI and no Google
features ship. Details: [plans/2026-10-11-browser-ui-grid.md](plans/2026-10-11-browser-ui-grid.md).

**History:** Alloy was tried first (2026-10-10) and set aside on the
assumption, from CEF's [#3448](https://github.com/chromiumembedded/cef/issues/3448),
that Alloy pages couldn't use Document Picture-in-Picture: a playing
`<video>` moved into any other kind of window is reloaded
(`HTMLMediaElement::ShouldReusePlayer`). Chrome style was used instead, but
it allows only one Chrome-style page per window, and moving one between
windows crashes, so it can't do tabs or a pane grid. Probes on 2026-10-11
showed that in this CEF version Alloy pages **can** use Document PiP: the
request reaches `OnBeforePopup` as a PiP popup, the browser hosts it in its
own frameless window, and moved media keeps playing. Alloy pages can also
share a window and move between panes and windows. Chrome style was
dropped entirely.

**Cost:** no Chrome extensions (the browser gets an extension system of
its own) and none of Chrome's UI (find, permission prompts, downloads and
so on are ours to provide).

## Repository layout

Two repos, both checked out side by side in `~/Repository/openp41ge/`.

```
browser/                     public: github.com/openp41ge/browser
  .github/workflows/         ci.yml, release.yml, cef-bump.yml
  AGENTS.md                  design doc / contributor guide (same role as in openp41ge/app)
  PLAN.md                    this file
  plans/                     dated plans, YYYY-MM-DD-*.md
  CEF_VERSION                pinned CEF binary build (CEF version + Chromium version)
  app/                       the browser shell (C++, CMake, CEF C++ API)
    src/
    resources/
  branding/                  product name, icons, bundle ids
  scripts/                   fetch-cef, build, package, sign, notarize, publish
  packages/
    web-extension/           Internet Utility Belt (WXT; Chrome, Firefox, Safari, Openp41ge browser)
    openp41ge-link/          browser<->app protocol schema + TypeScript client for openp41ge
  patches/                   empty unless Phase 7 adopts a CEF source build

browser-tests/               private: github.com/openp41ge/browser-tests
  .github/workflows/         test.yml (runs against builds of the public repo)
  unit/                      C++ unit tests for app/ (GoogleTest), built against a browser checkout
  smoke/                     launch/load/play/login/persist/pop-out checks against a built .app
  packages/                  tests for web-extension and openp41ge-link (Vitest)
  fixtures/                  local test pages (e.g. a video page, pop-out targets)
```

## Tests

All tests live in the **private** `openp41ge/browser-tests` repo; the public
repo contains no tests.

- **Unit tests** compile against the public repo's sources: the test build
  checks out `openp41ge/browser` at the commit under test and adds the tests
  as an extra CMake target.
- **Smoke tests** drive a built, signed `.app`:
  - launch
  - load fixture pages
  - play video
  - persist a session across restarts
  - later, pop out an element
- **Package tests** (Vitest) cover `packages/web-extension` and
  `packages/openp41ge-link`.
- **How results reach the public repo:** the public repo's CI builds the app
  and then triggers the private repo's test workflow (`repository_dispatch`
  with the commit SHA and build artifact id). The private workflow runs the
  tests and posts a **commit status** (`browser-tests`) back to the public
  commit. Branch protection on `master` and the release workflow both require
  that status.
- **Pull requests from forks:** GitHub withholds secrets from fork PRs, and
  running untrusted code next to the private tests could leak them. So fork
  PRs get the public build check only; a maintainer triggers the private test
  run manually after reviewing the code.
- **Trade-off:** outside contributors can't run the tests locally. CONTRIBUTING.md
  says so, and the `browser-tests` status shows them pass/fail.

## GitHub, CI and releases

Everything builds and releases on GitHub; nothing is built or published from
a laptop.

**Workflows in `openp41ge/browser`:**

- **`ci.yml`** runs on push and PR to `master`, on GitHub-hosted macOS Apple
  Silicon runners (`macos-latest`):
  - fetch the pinned CEF binary (cached by `CEF_VERSION`)
  - CMake build
  - upload the unsigned `.app` as an artifact
  - dispatch to `browser-tests` (skipped for fork PRs; see **Tests**)
- **`release.yml`** runs on pushing a tag `v*`:
  1. Build in Release mode for Apple Silicon and Intel (the Intel half
     cross-compiled on the same runner), and merge them into a universal app
     (`scripts/make-universal`).
  2. Sign with the Developer ID certificate (imported into a temporary
     keychain from secrets), with the hardened runtime and each process's
     entitlements (`scripts/sign-app`), notarize with `notarytool`, and
     staple (`scripts/notarize`).
  3. Package a signed, notarized `.dmg` (`scripts/make-dmg`), named like
     openp41ge code's (`openp41ge-explorer-<version>-universal.dmg`), and
     generate `SHA256SUMS`. The `.dmg` is both the download and the update
     archive.
     dmgbuild writes its Finder window (the app, an Applications link to
     drag it onto, and a branded background) without scripting Finder, so
     it runs headless.
  4. Wait for `browser-tests` to pass on the tagged commit (a release is
     blocked if it fails).
  5. Sign the update with Sparkle's EdDSA key and generate `appcast.xml`.
  6. Create the **GitHub Release** with auto-generated notes, plus the
     CEF and Chromium versions, and attach the `.dmg`, `appcast.xml` and
     `SHA256SUMS`.
  - Tags with a suffix (`v0.3.0-beta.1`) become GitHub **pre-releases**.
    GitHub's `latest` skips them, so installed apps don't update to them;
    a Sparkle beta channel comes with Phase 1.
- **`cef-bump.yml`** runs on a schedule (Phase 1). It checks the CEF builds
  index and opens a PR bumping `CEF_VERSION`.

**Auto-update:** the app's Sparkle feed URL is
`https://github.com/openp41ge/browser/releases/latest/download/appcast.xml`,
which GitHub redirects to the newest release's asset. No separate update
server is needed. The app checks it daily, and an update it finds waits for
the user to accept it (decided 2026-10-13), as Chrome's do: the top bar's
menu button says "Update available", and its menu starts with the update,
which opens Sparkle's window for it (what's new, Install Update). Nothing
installs without that.

**Versioning:** the app uses its own semver (`v0.1.0`, …), independent of
Chromium. Each release's notes state the CEF and Chromium versions it ships.

**Repository secrets (public repo):**

| Secret | Purpose |
|---|---|
| `MACOS_CERT_P12`, `MACOS_CERT_PASSWORD` | Developer ID Application certificate |
| `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID` | `notarytool` (Apple ID with an app-specific password, as `openp41ge/code` uses) |
| `SPARKLE_ED_PRIVATE_KEY` | Signing update archives |
| `CI_APP_CLIENT_ID` (org variable), `CI_APP_PRIVATE_KEY` (org secret) | The `openp41ge-ci` GitHub App, shared only with `browser` and `browser-tests` (see below) |

**Why a cross-repo credential is needed:** each workflow's built-in
`GITHUB_TOKEN` only works inside its own repo. The public CI must *trigger* a
run in `browser-tests`, and that run must *report its result* back onto the
public commit.

**The `openp41ge-ci` GitHub App** provides that:

- **Owner and install:** owned by the `openp41ge` org and installed only on
  `browser` and `browser-tests`.
- **Webhook:** none.
- **Repository permissions:**
  - Actions: read (the private run downloads the public build artifact)
  - Commit statuses: read & write (post the `browser-tests` result)
  - Contents: read & write (required to send `repository_dispatch`)
  - Metadata: read
- **Tokens:** each workflow mints a short-lived token with
  `actions/create-github-app-token`, scoped to the single repo and the single
  permission it needs (e.g. `permission-contents: write` to dispatch).
- **Results:** reported as plain **commit statuses**, not check runs, because
  check-run summaries are publicly visible on the public repo.
- **Key handling:** the private key lives only in GitHub secrets; to rotate,
  generate a new key on the app page and delete the old one.
- **Where the credentials live:** on GitHub's Free plan, org-level secrets
  and variables don't reach **private** repos' workflows. So `browser` uses
  the org secret and variable, while `browser-tests` has its own repo-level
  `CI_APP_CLIENT_ID` and `CI_APP_PRIVATE_KEY` (a separate key of the same
  app). On a paid plan, both could use the org-level ones.
- **Minutes:** the private repo's macOS runs count against the Free plan's
  private-repo minutes, and macOS minutes are billed at a multiple of Linux
  minutes. Watch usage once tests grow, and consider a paid plan or a
  self-hosted Mac runner for `browser-tests`.

Secrets are never exposed to fork PR workflows.

**Repo settings:** branch protection on `master` (require `ci` and
`browser-tests` checks, require PR review), tag protection for `v*`, and
GitHub's private vulnerability reporting turned on (for `SECURITY.md`).

## Approach

### Phase 0: Branded CEF shell that ships

Prove the toolchain end to end before features.

- `scripts/fetch-cef` downloads the pinned binary distribution for the
  platform. CMake builds `app/` against it, starting from CEF's
  [cef-project](https://github.com/chromiumembedded/cef-project) /
  `cefclient` structure.
- A minimal browser: one window, one Chrome-style browser, persistent profile
  in the user data dir.
- Branding: product name, icons, macOS bundle id, and the helper app bundles
  CEF requires on macOS.
- Package, sign, notarize, and auto-update via
  [Sparkle](https://sparkle-project.org/), all through the GitHub workflows
  above. `ci.yml`, `release.yml` and the `browser-tests` dispatch and status
  loop are part of this phase, not added later.
- `browser-tests`: the first smoke tests (launch, load a fixture page, play
  video, session persists) and the status reporting back to the public repo.
- Repo settings: branch protection, tag protection, secrets.
- **Exit criteria:** pushing tag `v0.1.0` produces a signed, notarized,
  universal GitHub release with a `.dmg`, and the release after it
  auto-updates an installed `v0.1.0`. (Updating was first proven in a VM:
  a signed build updated itself from a local appcast.) The browser loads sites, plays YouTube, and keeps logins across
  restarts. `browser-tests` gates both `master` and the release.

### Phase 1: Update automation

- `cef-bump.yml` watches the CEF builds index for new builds on the current
  branch and new branches. It opens a PR bumping `CEF_VERSION`. The usual CI
  and `browser-tests` checks run on it.
- Release channels:
  - **beta:** GitHub pre-release tags, cut automatically from merged bumps
  - **stable:** normal tags, after `browser-tests` passes and a person signs off
- **Response targets:**
  - in-the-wild zero-days: within **48 hours** of the CEF build carrying the fix
  - other security releases: within **7 days**
  - new milestones: within **2 weeks**
- **Measure CEF's lag behind Chrome stable** for security fixes during this
  phase. If it's regularly too slow for the zero-day target, that's an input to
  Phase 7.

### Phase 2: DOM pop-out spike (done)

**Outcome (2026-10-10): it works.** See
[plans/2026-10-10-dom-popout-spike.md](plans/2026-10-10-dom-popout-spike.md)
for the results; the pop-out moves into the browser per
[plans/2026-10-10-popout-in-app.md](plans/2026-10-10-popout-in-app.md).

A spike target (`spikes/dom-popout/`, now removed) proved the approach before
any browser UI was built: our own window with a Chrome-style page (YouTube),
and a pop-out window that the player **moves into**.

**How it works:**

1. **Open a Document PiP window.** A script in the page calls
   `documentPictureInPicture.requestWindow()`. CEF creates it frameless
   (`UseFramelessWindowForPictureInPicture`). It needs a user gesture: the
   browser runs the script as one (`AllowPictureInPictureWithoutUserActivation`
   had no visible effect).
2. **Place it.** The script moves and sizes the window over the element
   (`AllowMoveForPictureInPicture`) and keeps it at the element's
   proportions.
3. **Move the element in.** The script copies the page's stylesheets and moves
   the element in, leaving a placeholder. It's the same DOM node with its
   listeners and state, and **media keeps playing**: Chromium keeps the player
   for moves into Document PiP windows.
4. **Forward events.** Events that bubble through the pop-out unhandled are
   passed on to the main document, where pages keep document-level listeners
   (drags, press-and-hold, keyboard shortcuts).
5. **Put it back on close.** Closing the window moves the element back.

**No throttling:** Chromium's background throttling is switched off, so the
original page runs at full speed while its element is elsewhere:

- `--disable-background-timer-throttling`
- `--disable-renderer-backgrounding`
- `--disable-backgrounding-occluded-windows`

**Success criteria (YouTube):**

- **Fits the window:** the player shows in the pop-out at the pop-out's size;
  resizing re-lays it out.
- **Controls work:** click to pause, scrub, settings menu, hover controls,
  keyboard shortcuts, fullscreen behaviour.
- **No lag:** no late or undone clicks, and controls appear and hide normally.
- **Works in the background:** the main window minimized or behind other
  windows changes nothing.
- **Returns cleanly:** closing the pop-out returns the player and playback
  continues.
- **Survives navigation:** navigating YouTube while the player is popped out
  is recorded, whatever happens.

**Known risk:** site scripts that look elements up in the main document can
lose track of a moved element. The spike measures how much this happens on
YouTube.

**Gestures** (product work, after the spike):

- long-press pops out and keeps dragging while the button is held
- inside the pop-out, quick clicks go to the page; press-and-hold or dragging
  past a threshold moves the window

### Phase 3: Browser MVP (our own UI)

Pages are Alloy style, so we build the browser UI: see
[plans/2026-10-11-browser-ui-grid.md](plans/2026-10-11-browser-ui-grid.md).
It's written in HTML/CSS/JS, rendered by its own browser view and talking to
the shell over CEF's message router, so it's hackable with the same web
tools as Openp41ge.

- **Tabs and navigation:** a top bar (back, forward, reload), a grid of
  panes split left/right with a tab bar each (like openp41ge), and a start
  page in new tabs for addresses and search.
- **Pages:** find-in-page, zoom, popups and new windows
- **Prompts and errors:** permission prompts, auth dialogs, certificate and
  network error pages
- **Data:** downloads with a downloads list, history, bookmarks
- **Our own keychain item:** CEF 154 keeps its encryption key (cookies and
  other stored secrets) in the keychain as "Chromium Safe Storage", the same
  item every unbranded Chromium or CEF app uses. If one of those already
  made it, macOS asks to share it, in a prompt naming Chromium. CEF 156 adds
  `CefSettings.keychain_service_name` and `keychain_account_name` (API
  15600): when it's stable, name the item per channel ("openp41ge explorer
  Safe Storage", and the development name for dev builds). Data encrypted
  with the old key (cookies, mostly) is lost once, so do it while users are
  few.

**Google features stay off** (see the decision above): smoke tests check
that sign-in, sync and Translate don't appear.

**Out of scope for the MVP:** sync, multiple profiles, password manager, DRM
(see Open Questions).

### Phase 4: Element pop-out as a product

- **Triggers:**
  - context menu "Pop out this element"
  - a shortcut that enters pick mode (hover to highlight, click to choose, step to parent/child)
  - long-press on a playing video
- **Site presets** (e.g. "YouTube player") come from extensions, not the
  browser: the browser's pop-out is generic, and Internet Utility Belt adds
  per-site behaviour on the shared page-side code (`packages/popout`).
  Browser tests never depend on live sites.
- **Persistence:** pop-outs restore with the session by reopening the source
  page and re-resolving the element (selector or preset). If an element can't
  be found again, the user is told rather than it silently failing.
- **Settings:** pop-out behaviour, presets, and the Openp41ge link.

### Phase 5: Openp41ge link (the app stays on Electron)

- **Protocol:** defined in `packages/openp41ge-link`. A Unix domain socket
  (named pipe on Windows) in the user's data dir, JSON-RPC messages, versioned
  schema, and capability negotiation on connect.
- **Browser side:** native code in `app/`.
- **App side:** an Openp41ge extension (`registerProcesses` backend +
  `registerRenderers` view, per the app's extension model) using the TS
  client.
- **First features:**
  - **Pop out into a pane:** the app reports a pane's screen rect, and the
    browser docks the pop-out window over it and keeps it glued there through
    moves, resizes, tab switches and z-order changes.
  - **Open in browser:** links from Openp41ge open in the browser, and
    Openp41ge can list and focus browser tabs.
  - **Drag between them:** URLs and pop-outs dragged across apps via OS drag
    and drop, mapped to the app's `DragPayload` kinds.
- **Keeping in sync** means protocol versioning and coordinated releases: each
  side declares the protocol versions it supports, and both refuse
  incompatible peers with a clear message.

### Phase 6: Internet Utility Belt in this repo

- Move `~/Repository/internet-utility-belt` to `packages/web-extension`
  (started 2026-10-11, carrying the YouTube and Shorts pop-out presets). It
  remains a normal web extension for Chrome, Firefox and Safari.
- Alloy-style pages don't load Chrome extensions, so its features reach the
  browser through an extension system of the browser's own (decided
  2026-10-13; it needs its own plan), not built into the browser. They're
  plain DOM code with host services passed in, which that system provides.
- In Chrome, Edge and Brave it stays a normal extension, using Document PiP
  directly.

### Phase 7: CEF source build gate (only if needed)

Switch from binary CEF to a CEF source build with our patches only for a
must-have that binaries can't provide:

- **Proprietary codecs** (H.264/AAC), if the codec decision requires shipping them.
- **Security lag:** if Phase 1 shows CEF binaries regularly miss our
  zero-day target.

If triggered, write a dedicated plan. Keep patches as small hooks with our
code in separate files (Brave's approach), and re-budget upkeep to the
fork-level numbers below.

### Phase 8: Open-source release

- `SECURITY.md`: disclosure address, supported versions (latest stable only),
  and the Phase 1 response targets. Be explicit that security fixes arrive via
  CEF, after Chrome.
- `CONTRIBUTING.md`: how to build, how to write a plan, and how testing works
  (tests are private; CI reports results on PRs).
- The GitHub workflows and releases already exist from Phase 0; this phase
  only polishes docs, issue templates and release notes.
- License: our code MIT (matching `openp41ge/app`). CEF is BSD-3-Clause and
  Chromium carries its own third-party licenses; ship the generated credits.

## Upkeep

| Task | Frequency | CEF binaries (this plan) | If Phase 7 adopts a source build |
|---|---|---|---|
| Security release | ~Weekly | Bump `CEF_VERSION`, rebuild the shell (minutes), smoke test, sign, ship: **~1 hr** | Re-apply patches, full rebuild (hours per platform), test, ship: **1–3 hrs** |
| New milestone (new CEF branch) | Every 4 weeks | Fix CEF API changes in our shell: **0.5–1 day** | Plus patch conflicts: **1–5 days** |
| Zero-day | Several per year | Ship as soon as CEF publishes the fixed build | Same-day patch and rebuild |
| Infrastructure | Ongoing | GitHub-hosted runners (free macOS minutes for public repos; the private test repo uses paid minutes), Apple Developer (~$99/yr) | Plus 100 GB+ checkouts and self-hosted build machines (too big for hosted runners) |

**People:** with CEF binaries, upkeep fits in a few hours a week of one
engineer for macOS. **Skills:** C++ and CEF's API (plus a little Objective-C++
for macOS windowing); not Chromium internals unless Phase 7 happens.

## Open Questions

1. **DRM (Netflix-style sites):** Widevine needs a license and macOS/Windows
   signing (VMP), e.g. via castlabs. Needed for v1?
2. **Google services:** no Chrome sync or Google account integration. Safe
   Browsing needs an API key under Google's terms. Do we use it, use an
   alternative, or document the gap?
3. **Icon and visual branding:** the name is settled; it still needs an
   icon. Note that "explorer" is also the name of the app's file explorer
   extension (`openp41ge-extension-explorer`), so docs and UI should say
   "openp41ge explorer" in full to avoid confusion.
4. **Pop-out window gesture conflict:** is press-and-hold-to-drag inside the
   window right, or should dragging use a modifier key or an edge strip?
5. **Apple Developer account:** set up (Developer ID Application
   certificate, team `AG73L2Q952`). `release.yml` needs its secrets (see
   DEVELOPMENT.md, "Releases") before the first release.

## Next steps

1. Create the `openp41ge-ci` GitHub App and its org secrets (see **GitHub, CI and releases**).
2. Phase 0: branded CEF shell, `ci.yml` + `release.yml`, the first
   `browser-tests` smoke tests with status reporting, and the first GitHub
   release (`v0.1.0`), signed and notarized.
3. Phase 1: `cef-bump.yml` and the beta/stable channels.
4. Phase 2: DOM pop-out spike: **done**, see
   [the results](plans/2026-10-10-dom-popout-spike.md).
5. Pop-out in the browser ([plan](plans/2026-10-10-popout-in-app.md)), then
   the tabs probe that decides the Phase 3 tabs design.
