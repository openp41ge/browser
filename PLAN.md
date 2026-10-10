2026-10-10

# openp41ge explorer

## Goal

An open-source web browser **built on CEF (the Chromium Embedded Framework)**,
released alongside Openp41ge and integrated with it. Its headline capability
is **element pop-out**: any part of a web page (a video player, a chat, a
dashboard widget) can be shown in its own native window while it stays live
in its original page. Clicks, keys and scrolling in the popped-out window go
back to the original element as real input, so the website keeps working
exactly as if nothing had moved.

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
| Shell language | C++ (CEF's first-class API) |
| Video codecs | Ship v1 **without** proprietary codecs (H.264/AAC); standard CEF binaries |
| Platforms | macOS on Apple Silicon first; others later |
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

The fix is to **leave the element in its page and only show it elsewhere**
(mirror the pixels, forward input). That needs control over windows, page
rendering and input delivery, which means owning the browser.

**Why CEF:**

- **No Electron** (ruled out for the browser).
- **No fork:** CEF ships **prebuilt Chromium binaries** for every Chrome
  release, so there's no 100 GB checkout, no multi-hour builds, and no patch
  series to carry.
- **Its public API has what element pop-out needs:** our own native windows,
  off-screen rendering with GPU shared textures, control of popup windows,
  trusted input injection, and DevTools protocol access.
- **Escape hatch:** if a must-have feature needs changes inside Chromium
  (e.g. giving an element its own layout viewport), CEF can be built from
  source with our patches. That's only adopted behind an explicit gate
  (Phase 7).

## Key CEF facts this plan depends on

As of CEF M128+ (see [CEF issue #3685](https://github.com/chromiumembedded/cef/issues/3685)):

- CEF runs on the **Chrome bootstrap** and can create two browser styles:
  - **Chrome style:** Chrome's UI and behaviour, including **Chrome extension
    support**.
  - **Alloy style:** minimal, embedder-drawn. **Required for windowless
    (off-screen) rendering**, which is the cleanest way to mirror pixels.
    **No Chrome extension support** (the Alloy extension API was removed in M128).
- Release branches track Chromium milestones. Within a branch the CEF API is
  frozen and only security/bug fixes land, published as automated binary
  builds at [cef-builds.spotifycdn.com](https://cef-builds.spotifycdn.com/index.html).
- Standard binary builds **exclude proprietary codecs** (H.264/AAC). Enabling
  them requires building CEF from source.

The tension between **extensions (Chrome style)** and **off-screen mirroring
(Alloy style)** is resolved by the Phase 2 spike, which tries both.

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
  1. Build in Release mode.
  2. Sign with the Developer ID certificate (imported into a temporary
     keychain from secrets), notarize with `notarytool`, and staple.
  3. Package a `.dmg` and generate `SHA256SUMS`.
  4. Wait for `browser-tests` to pass on the tagged commit (a release is
     blocked if it fails).
  5. Sign the update with Sparkle's EdDSA key and generate `appcast.xml`.
  6. Create the **GitHub Release** with auto-generated notes, plus the
     CEF and Chromium versions, and attach the `.dmg`, `appcast.xml` and
     `SHA256SUMS`.
  - Tags with a suffix (`v0.3.0-beta.1`) become GitHub **pre-releases** and the
    Sparkle beta channel.
- **`cef-bump.yml`** runs on a schedule (Phase 1). It checks the CEF builds
  index and opens a PR bumping `CEF_VERSION`.

**Auto-update:** the app's Sparkle feed URL is
`https://github.com/openp41ge/browser/releases/latest/download/appcast.xml`,
which GitHub redirects to the newest release's asset. No separate update
server is needed.

**Versioning:** the app uses its own semver (`v0.1.0`, …), independent of
Chromium. Each release's notes state the CEF and Chromium versions it ships.

**Repository secrets (public repo):**

| Secret | Purpose |
|---|---|
| `MACOS_CERT_P12`, `MACOS_CERT_PASSWORD` | Developer ID Application certificate |
| `APPLE_API_KEY`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER` | `notarytool` (App Store Connect API key) |
| `SPARKLE_ED_PRIVATE_KEY` | Signing update archives |
| `CI_APP_ID` (org variable), `CI_APP_PRIVATE_KEY` (org secret) | The `openp41ge-ci` GitHub App, shared only with `browser` and `browser-tests` (see below) |

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
  `actions/create-github-app-token`, scoped to the single repo it needs.
- **Results:** reported as plain **commit statuses**, not check runs, because
  check-run summaries are publicly visible on the public repo.
- **Key handling:** the private key lives only in the org secret and a
  password manager. Rotate it by generating a new key and deleting the old.

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
- **Exit criteria:** pushing tag `v0.1.0-alpha.1` produces a GitHub
  pre-release with a `.dmg`, and an older test release auto-updates to it.
  Once the Apple Developer account is set up, the same pipeline produces a
  signed, notarized stable release. The browser loads sites, plays YouTube, and keeps logins across
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

### Phase 2: Element pop-out spike (decides the browser architecture)

Build both candidates in the shell, measure them on YouTube 1080p60 and one
non-video site, and pick one.

**A. Chrome-style tabs, mirrored by element capture inside the page**

- Tabs are Chrome-style browsers, so Chrome UI and extensions work.
- An injected script captures its own tab (`getDisplayMedia`, auto-approved by
  our permission handler, so there's no prompt) and narrows it to the element
  (`RestrictionTarget.fromElement` + `restrictTo`, falling back to
  `CropTarget` + `cropTo`).
- The pop-out is a same-origin popup (`window.open`). CEF's `OnBeforePopup`
  lets the shell create it as **our own window**: frameless, always on top,
  positioned over the element, aspect-locked. The capture stream plays in a
  `<video>` inside it.
- Input: pop-out events are mapped to the element's page coordinates and
  injected as **trusted** input through the DevTools protocol
  (`Input.dispatchMouseEvent` / `dispatchKeyEvent` via `ExecuteDevToolsMethod`).

**B. Alloy-style windowless tabs, mirrored by off-screen rendering**

- Tabs are Alloy-style windowless browsers. The shell draws every page itself
  from shared GPU textures (`OnAcceleratedPaint`, IOSurface on macOS).
- The pop-out is simply another view drawing the element's region of the same
  texture: zero copies, perfectly in sync.
- Input: `SendMouseEvent` / `SendKeyEvent` / `SendMouseWheelEvent` with mapped
  coordinates.
- Cost: **no Chrome extensions**, and we build **all browser UI** (tabs,
  toolbar, menus, dialogs, permission prompts) ourselves.

**Shared to both:**

- **Element tracking:** element rect, visibility and removal are reported to
  the shell each frame (an injected script over CEF's message router, or the
  DevTools protocol's DOM methods).
- **Keeping the page live:** the source browser keeps rendering and running
  timers at full rate while a pop-out is open, even if its tab is hidden.
  Chrome-style capture already keeps a page active; in windowless mode we
  control hidden state directly.
- **Gestures:**
  - Long-press pops out and keeps dragging: the window is created under the
    cursor and follows it while the button is held.
  - Inside the window, quick clicks go to the page; press-and-hold or dragging
    past a threshold moves the window. Edges resize, with the aspect ratio locked.

**Success criteria:**

- 60 fps and under 1 frame of added latency
- CPU/GPU cost within ~10% of normal playback
- scrubbing, settings menus, hover states and keyboard shortcuts all work through the pop-out
- source tab hidden: everything keeps working

**Decision rule:** prefer **A** if it meets the criteria (we keep Chrome's UI
and extensions for free). Choose **B** only if A's quality or latency falls
short. Write the result up in `plans/` with numbers.

### Phase 3: Browser MVP

Scope depends on the Phase 2 decision:

- **If A (Chrome style):** Chrome's own UI provides tabs, the address bar,
  menus, downloads, permission prompts and settings. The MVP is mostly shell
  work: window management, profile, branding, `chrome://` pages we keep or
  hide, and default search engine.
- **If B (Alloy style):** we build the browser UI ourselves:
  - tabs, address bar with search, back/forward/reload
  - downloads, permission prompts, auth and certificate error pages
  - find-in-page, zoom, popups, history, bookmarks
  This is substantially larger, so it gets its own plan.

Either way, out of scope for the MVP: sync, multiple profiles, password-manager
work beyond what Chrome style provides, and DRM (see Open Questions).

### Phase 4: Element pop-out as a product

- **Triggers:**
  - context menu "Pop out this element"
  - a shortcut that enters pick mode (hover to highlight, click to choose, step to parent/child)
  - long-press on a playing video
- **Site presets** (e.g. "YouTube player"), defined in the same rule format the
  web extension uses.
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

- Move `~/Repository/internet-utility-belt` to `packages/web-extension`. It
  remains a normal web extension for Chrome, Firefox and Safari.
- **If A (Chrome style):** it also loads in the Openp41ge browser as an
  extension. The browser exposes its engine powers (e.g. `popOutElement`) to
  pages through an injected bridge (CEF message router), which the extension
  calls via DOM events. Feature detection picks the native pop-out in our
  browser and the Document PiP fallback in Chrome.
- **If B (Alloy style):** extensions don't load. The browser runs the
  extension's feature modules directly as injected scripts. This works because
  features are plain DOM code with host services injected
  (`core/run-feature.ts`); add a CEF host adapter alongside the WXT one.

### Phase 7: CEF source build gate (only if needed)

Switch from binary CEF to a CEF source build with our patches only for a
must-have that binaries can't provide:

- **Independent element viewport:** a popped-out element laid out at the
  window's size rather than mirrored and scaled. This touches Blink's
  single-viewport assumptions and would need a dedicated plan.
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
5. **Apple Developer account:** to be provided later. Until then,
   `release.yml` skips Developer ID signing and notarization when those
   secrets are missing. It ad-hoc signs instead and publishes **pre-releases
   only**, because macOS will warn about or block an un-notarized download.
   The first stable release waits for the account.

## Next steps

1. Create the `openp41ge-ci` GitHub App and its org secrets (see **GitHub, CI and releases**).
2. Phase 0: branded CEF shell, `ci.yml` + `release.yml`, the first
   `browser-tests` smoke tests with status reporting, and the first GitHub
   pre-release (`v0.1.0-alpha.1`), unsigned until the Apple account arrives.
3. Phase 1: `cef-bump.yml` and the beta/stable channels.
4. Phase 2 spike: A vs B, ending in the architecture decision write-up.
