2026-10-14

**Status: planned.**

# Extension system

The browser's own extension system, decided 2026-10-13 (Phase 6 of
[PLAN.md](../PLAN.md)). Pages are Alloy style and don't load Chrome
extensions, so site behaviour such as the YouTube and Shorts pop-out
reaches the browser through extensions of the browser's own (the
extensions themselves live in openp41ge/browser-community, one per
feature; see **The community repo**).
The browser's pop-out stays generic; extensions add per-site presets.

Extensions come from two places:

- **GitHub:** installed from a repo's releases.
- **Local folders:** written by hand, or by AI in the openp41ge code editor.
  The browser has no AI features; it only loads the folder (see **Local
  extensions**).

Both are untrusted code that runs in the user's pages, so both go through
the same install review and run under the same rules.

## Format

An extension is a folder with a manifest and plain JavaScript, CSS and
HTML. Nothing is built or installed with npm in the browser: an extension
that needs a build ships the built folder.

```
my-extension/
  openp41ge-extension.json
  youtube.js
  youtube.css
  guide.html
```

```json
{
  "manifestVersion": 1,
  "id": "youtube-tools",
  "name": "YouTube tools",
  "version": "0.3.0",
  "description": "An example: a pop-out button and a Shorts option.",
  "contentScripts": [
    {
      "matches": ["*://*.youtube.com/*"],
      "js": ["youtube.js"],
      "css": ["youtube.css"],
      "runAt": "document_idle",
      "feature": "youtube-pip"
    }
  ],
  "features": [
    { "id": "youtube-pip", "name": "Pop out YouTube videos", "enabledByDefault": true }
  ],
  "config": {
    "type": "object",
    "properties": {
      "autoAdvanceShorts": {
        "type": "boolean",
        "title": "Play the next Short when one ends",
        "default": true
      },
      "buttonPosition": {
        "type": "string",
        "title": "Pop-out button position",
        "enum": ["top", "bottom"],
        "default": "top"
      }
    }
  },
  "pages": [
    { "path": "guide.html", "title": "YouTube tools guide" }
  ]
}
```

- `matches` uses Chrome's match-pattern syntax, so the site lists read the
  same as a WebExtension's. They are the extension's only permissions.
- `runAt` is `document_start` or `document_idle` (the default).
- A content script with a `feature` runs only while that feature is on.
- `features` lists the extension's on/off toggles.
- `config` and `pages`: see **Settings** and **Extension pages**.
- The format is small on purpose: easy to write by hand or by AI, and easy
  to review.

## Extension UI is pages, not overlays

The browser gives extensions no UI of their own over the browser or over
pages: no popups from a toolbar button, no overlay windows or panels
outside the page. Anything an extension wants to show outside a page is a
**page**, opened as an ordinary tab.

- **In-page UI is fine:** a content script can add anything to the page's
  own DOM, including modals in the page, such as the pop-out button on
  YouTube's player.
- Settings, setup, and anything that isn't about the page the user is on
  go in an extension page.

## Extension pages

- Served from the extension's folder at
  `openp41ge-extension://<id>/<path>`: a scheme of their own, so each
  extension's pages are their own origin, and none share the browser UI's
  channel (`openp41ge://ui/`).
- Only files listed in `pages` open as pages; other files in the folder
  (scripts, styles, images) can be loaded by them.
- Opened from the Extensions page, or by the extension
  (`openp41ge.openPage(path)`), always as a new tab next to the current one.
- No remote scripts: a page loads scripts only from its own extension
  (content security policy).
- The page with `"role": "settings"` is the one the Extensions page opens
  for **Settings**.
- Extension pages get `openp41ge.config` (see **Settings**) and the feature hosts,
  so they can read and change their extension's settings and talk to its
  content scripts.

## Settings

Settings follow the openp41ge code editor's extension config contract
(`openp41ge-sdk`'s `config.ts`), so an extension's config means the same
thing in both apps, and the editor's AI writes one kind of schema.

**Optional, as in Chrome:** an extension needn't have settings, and
needn't keep them in `config`. Its pages are an origin of their own with
the web's storage (`localStorage`, IndexedDB, …), as Chrome's extension
pages are, and a `"role": "settings"` page can keep settings however it
likes. `config` is what the browser offers: declared there, settings are
stored, merged and checked by the browser, and get its settings page (the
JSON view, and the form view later) with no page of the extension's own.
Without `config`, an extension's scripts get `{}` and the browser's
settings page is Not Found. (Decided 2026-10-14, after asking what Chrome
does: it doesn't block storage in extension pages either.)

**Declaring (developer):** `config` in the manifest is one JSON Schema
(draft 2020-12) with an object at the root:

- Checked keywords, as in `config.ts`: `type`, `properties`, `required`,
  `additionalProperties`, `items`, `enum`, `minimum`, `maximum`. Other
  keywords (`title`, `description`, …) are kept for the editor and the form.
- `default`: the developer's value, checked against its own schema when the
  extension loads.
- A property **without** a default is **user-provided**: the extension has
  no value for it until the user gives one. If it's also in `required`, the
  extension shows "Needs setup" and its content scripts don't run until it's
  set.
- `"secret": true` (strings, our keyword): kept in the macOS Keychain
  instead of the profile, never shown in the JSON view (see **Editing**),
  and never readable from content scripts.

**Storing (user):** only what the user wrote is stored, per extension, in
the profile (`openp41ge Extensions/<id>/config.json`, beside Chromium's own
`Extension …` folders; secrets in the Keychain). Defaults are never copied
into it.

**Merging (at runtime):** the user's values merged over the schema's
defaults, as `config.ts`'s `mergeConfig` does. So:

- An update that changes a default reaches everyone who hasn't changed that
  value, and leaves alone those who have.
- A stored value that no longer fits the schema after an update (its type
  changed, or the property was removed) is reported by `configErrors` and
  shown on the settings page; the default is used until the user fixes or
  resets it, and the stored value isn't lost.
- **Reset** removes the user's value, so the default applies again.

The browser's merge and checks must give the same results as `config.ts`:
the code repo's tests for it are run against the browser's version too (see
**Shared code from the code editor**).

**Feature toggles** stay separate from config: on/off per feature, shown on
the Extensions page, defaulting to `enabledByDefault`.

**API** (content scripts and extension pages, scoped to their extension):

- `openp41ge.config.get()`: the merged config.
- `openp41ge.config.onChange(callback)`: called with the new merged config
  in every page of the extension, whichever page made the change.
- Extension pages only: `openp41ge.config.set(value)` (the user's values,
  checked against the schema; rejected if invalid) and
  `openp41ge.config.reset(key)` (a top-level setting); also `values()`,
  `schema()` and `problems()` (see **Step 5: what was built**). A page in a
  site can't change settings.

## Editing settings

Every extension with a `config` gets a settings page from the browser,
with two views of the same values, as the code editor's workspace editor
has:

- **Form:** built from the schema. A field per property: a toggle for
  `boolean`, a number field for `number`/`integer` (with `minimum` and
  `maximum`), a menu for `enum`, a text field for `string` (masked if
  `secret`), a list for `array`, a group for `object`. `title` and
  `description` label it; defaults show faded until overridden; each field
  has Reset; user-provided fields left empty are marked, required ones
  first.
- **JSON:** the code editor's `<json-editor>` with the schema (tooltips,
  key suggestions) and `showDefaults`, so defaults are visible faded and the
  stored file stays only what the user wrote. Secrets are left out of this
  view.

Both views write the same user values; an invalid edit in the JSON view is
shown and not saved. An extension can still have its own pages
(`"role": "settings"` makes the Extensions page link to it as well), but it
needs none to have settings.

## Shared code from the code editor

From the code repo (`~/Repository/openp41ge/code`):

- **`<json-editor>`** (`openp41ge-sdk-uikit/json-editor`): a Lit web
  component with no Electron or Node dependencies; themed by CSS variables
  (`--bg-primary`, `--accent`, `--font-mono`, `--je-*`, …), which the
  browser's `app/ui/shared/theme.css` defines.
- **Config logic** (`openp41ge-sdk/src/config.ts`): `configDefaults`,
  `configErrors`, `mergeConfig`, `validateConfigSchema`.
- **Form view:** doesn't exist yet. The workspace editor's form is written
  by hand for its two fields. A generic schema form (`<json-form>`) belongs
  next to `<json-editor>` in `openp41ge-sdk-uikit`, so the code editor can
  use it for its own extension config too.

These packages are private and use pnpm workspace dependencies, so the
browser can't install them. Instead:

- **A copy, for now:** `scripts/update-uikit` builds a **self-contained
  bundle** (Lit and the `openp41ge-core-*` packages included) from a code
  worktree's source, with the code repo's own Vite and nothing changed
  there (`scripts/uikit/`: what's taken, and how it's bundled). It writes
  `third_party/openp41ge-uikit/uikit.js`, checked in, and the commit it came
  from (`SOURCE`). Updates are deliberate, like CEF bumps. Done 2026-10-14
  for `<json-editor>` and the config logic.
- Moving the UI kit to a repo of its own, for every repo to use, is left
  for later; only the script's source changes then.
- Checking and merging config runs only in JavaScript, with that bundle:
  in the settings page, and in the `openp41ge` runtime in content scripts
  and extension pages. The browser process stores and passes on the
  schema and the user's values but doesn't interpret them, so there's one
  implementation and no C++ port. Because merging happens when values are
  read, a value saved around the checks still falls back to its default.
  (`mergeConfig` itself doesn't drop invalid values; the runtime checks
  each with `configErrors` first.)

## What content scripts get

The browser defines `globalThis.openp41ge` for content scripts:

- **`openp41ge.popout`:** the page side of pop-out (`packages/popout`'s
  `core.js`), so an extension adds a site preset instead of its own copy.
- **`openp41ge.config`:** read-only (see **Settings**).
- **`openp41ge.feature(id)`:** a feature's host, matching Internet Utility
  Belt's `FeatureHost` (`packages/web-extension/src/core/feature.ts`):
  - `enabled` and `onEnabledChange(callback)`: the user's toggle, live
    (see **Feature toggles**).
  - `broadcast(message)`: to the same feature in the other tabs where it
    runs, and to the extension's open pages, resolving with their replies.
  - `onMessage(handler)`: answers those broadcasts.
- **`openp41ge.openPage(path)`:** opens one of the extension's pages in a
  new tab.

That's the whole API. Messages travel through the browser process, which
delivers them only within the same extension. There is no emulation of
Chrome's extension APIs (`chrome.*`, background pages); an extension that
needs more asks for it here first.

## The community repo

Decided 2026-10-14: the browser's extensions live in
**openp41ge/browser-community** (local: `~/Repository/openp41ge/
browser-community`, worktree `master`), **one extension per feature**, not a
utility belt of many. Internet Utility Belt (`packages/web-extension`, a
WXT extension for Chrome, Firefox and Safari) is retired; its YouTube and
Shorts pop-out is the repo's first extension, `extensions/youtube-popout`.

- **Layout:** `extensions/<id>/` with `openp41ge-extension.json` and `src/`;
  `types/openp41ge.d.ts` (the `openp41ge` API, and the pop-out's types copied
  from `packages/popout/src/core.d.ts`).
- **TypeScript, built for releases** (decided 2026-10-14):
  `scripts/build.mjs` bundles each top-level `src/*.ts` (esbuild, one plain
  script each) and copies the rest into `dist/<id>/`, which is what the
  browser loads (`--extension-folder=dist/<id>` while developing) and what a
  release zips. The browser still never runs a build.
- **Releases, one per extension and version:** a tag `<id>-v<version>`
  (matching the manifest) runs `.github/workflows/release.yml`, which
  publishes `<id>-<version>.openp41ge-extension.zip` and its SHA-256.
- **Live checks** (by hand, never a gate) are in browser-tests' `live/`
  (`live/youtube-popout.mjs`).

## Installing from GitHub

- **From a release, not the source:** the user gives a repo
  (`owner/repo`, or its URL); the browser lists its releases and installs an
  asset named `*.openp41ge-extension.zip`. It never runs the repo's build.
- **Many extensions in one repo** (as openp41ge/browser-community): each has
  its own releases, tagged `<id>-v<version>`, with
  `<id>-<version>.openp41ge-extension.zip`. The browser lists the repo's
  extensions (by tag prefix), installs one, and checks for updates among
  that extension's releases only. A repo with one extension may tag
  `v<version>`.
- **Review before installing:** name, version, repo, and the sites it runs
  on, in plain words ("Runs on youtube.com"), and the settings it will ask
  for. Nothing runs until the user accepts. If it has required settings,
  its settings page opens next.
- **Pinned:** the installed record keeps the repo, tag and the zip's
  SHA-256.
- **Updates:** the browser checks for newer releases and offers them. An
  update that adds sites is reviewed again; one that doesn't installs on
  accept. User settings carry over (see **Merging**).
- **Unpacking:** paths in the zip are checked (no absolute paths, no `..`,
  no links) and the manifest is validated before anything is written to the
  profile.

## Local extensions

- **Load a folder:** the browser runs a local folder in place, after the
  same review. This is how the openp41ge code editor's AI-written extensions
  reach the browser: the editor writes the folder, the browser loads it.
- **Reload:** a reload command picks up changes and re-runs the
  extension in matching open pages and reloads its open pages. Watching the
  folder for changes can come later.
- Local extensions are labelled as such and never auto-update.
- Settings are kept by extension id, so they survive reloads and moving
  from a local folder to a GitHub install.

## In the browser

- **`ExtensionManager`** (`app/src/extensions/`): installed extensions in
  the profile (`openp41ge Extensions/`), their manifests, install, update, remove,
  reload.
- **Config storage:** each extension's schema (from the manifest) and the
  user's values (profile and Keychain), passed to its pages and content
  scripts, with change notifications. Checking and merging happen in
  JavaScript (see **Shared code from the code editor**).
- **Injection:** each extension gets an isolated world in each page
  (`Page.addScriptToEvaluateOnNewDocument` with a `worldName`, through
  `DevToolsClient`, registered as the page is created). What it runs is the
  `openp41ge` runtime, which, in the top frame only, matches the URL against
  the extension's content scripts whose features are on and whose required
  settings are set, adds their CSS, and runs their scripts at their
  `runAt`. Checked by the first probe (**To check early**).
- **Extension pages:** a scheme handler for `openp41ge-extension://`,
  serving files listed in the manifest (like `ui_scheme` serves
  `openp41ge://ui/`).
- **Messages:** a channel from content scripts and extension pages to the
  browser process that accepts only extension calls and checks the
  sender's extension (by the content script it injected, or the page's
  origin). It never reaches the browser's UI channel (`app/src/ui/`).
- **UI:** an Extensions page (`openp41ge://extensions`, our own HTML UI):
  installed extensions with their source, version, sites and status ("Needs
  setup"); a toggle per feature; Settings (the extension's page or the
  settings page); Install from GitHub, Load folder, Reload, Remove, Check for
  updates.

## Rules

- An extension runs only in pages its `matches` cover, and only in the
  main frame for now.
- Extensions never run in the browser's own UI pages, in other
  extensions' pages, or in pop-out windows' controls.
- Extension UI is pages in tabs (see **Extension UI is pages, not
  overlays**).
- Turning an extension or feature off takes effect without a reload (the
  feature tears itself down, as in Internet Utility Belt today).
- A broken extension doesn't break the page: script errors are caught and
  shown on the Extensions page.

## To check early (risks)

- ~~**Isolated worlds**~~: checked 2026-10-14 (probe against the 0.1.7
  build, driven over DevTools from Node like the smoke tests). Content
  scripts run in their own JavaScript world, as Chrome's do:
  `Page.addScriptToEvaluateOnNewDocument` with a `worldName`, sent before
  the page loads, which the browser will send through its own
  `DevToolsClient`.
  - The script runs at document start, before the page's own scripts
    (`document.documentElement` doesn't exist yet: the runtime waits for it
    before adding CSS or DOM), and again in each new document after a
    navigation.
  - The page and the script share the DOM but not globals: neither sees
    the other's (`openp41ge` stays out of the page's reach).
  - A real click on a button the script added gives user activation:
    `documentPictureInPicture.requestWindow()` from the isolated world works.
  - `packages/popout`'s `core.js` loaded into the isolated world pops out an
    element: it moves into the PiP window, its media keeps playing (not
    reloaded), the browser makes the window frameless with its controls,
    and closing puts the element back. The page's world doesn't see
    `__openp41ge`.
  - To handle in the runtime: the script runs in every frame, so the
    runtime checks it's the top frame and that the URL matches before
    running an extension's code. An already-open page (installing or
    reloading an extension) needs `Page.createIsolatedWorld` and
    `Runtime.evaluate` in it instead; not probed, but the same mechanism.
  - So the fallback (scripts in the page's world) isn't needed.
- **GitHub API limits:** unauthenticated requests are rate-limited (60 an
  hour per IP); enough for installs and daily update checks.

## Step 2: what was built

- **Loading:** `--extension-folder=<folder>[:<folder>…]` loads local
  folders for that run (`src/extensions/extension.cc` reads and checks the
  manifest: unknown keys, missing files and paths outside the folder are
  errors, and the extension isn't loaded; the log says why). Installing,
  and remembering what's installed, come with the Extensions page.
- **Injection** (`src/extensions/extension_manager.mm`): for each page,
  `Page.enable` (scripts added for new documents run only with it on), then
  per extension `Page.addScriptToEvaluateOnNewDocument` in the world
  `openp41ge-extension:<id>`, and the same script in the current document
  (`Page.createIsolatedWorld`, `Runtime.evaluate`).
- **First page of a tab:** the calls reach a new page's renderer only after
  its first page has started, so with extensions loaded a tab's page starts
  on `about:blank` and loads its address once they're answered (at most 2
  s). Its tab never shows the blank page, and it's cleared from the page's
  history (`Page.resetNavigationHistory`) as the real one commits.
- **Pages opened by a page** (`window.open`, links to new windows) can't
  be held back: their first page gets the extension once it's added,
  late (so `document_start` scripts run after the page's own there); later
  pages from the start.
- **Runtime** (`app/extensions/runtime.js`): one function, called with the
  extension, its JS files as functions (each file is a function's body:
  no `eval`, so a page's CSP doesn't matter), and `core.js`. It runs once per
  document (marked on the document: a page opened by `window.open` hands
  its blank document's window on to its real one), in the top frame,
  matching patterns against the path and query as Chrome does. CSS goes in
  as constructed style sheets, which a page's CSP doesn't block.
  `openp41ge.extension` and `openp41ge.popout` (core.js, loaded in the
  extension's world when first used).
- **Not in private windows.** Features run as `enabledByDefault` says until
  toggles exist (step 4).
- **Tests** (`browser-tests`, `smoke/extensions.mjs`, fixtures in
  `fixtures/extensions/`): document start before the page's scripts,
  separate worlds, CSS (also under a strict CSP), a feature off by default,
  a throwing file not stopping the next, top frame only, pop-out from an
  extension's button, navigation, pages opened by a page, patterns not
  matching, a broken manifest, private windows.

## Step 4: what was built

- **Manifest:** `config` must be an object; the browser keeps it as JSON
  and doesn't interpret it.
- **The user's side**, read as an extension loads, from
  `<profile>/openp41ge Extensions/<id>/`: `config.json` (their values) and
  `features.json` (`{ "<feature id>": bool }`, the toggles they changed).
  A file that isn't a JSON object is logged and read as empty, and left
  alone. Nothing writes them yet: the settings page (steps 5 and 6) and the
  Extensions page (step 10) will; by hand until then, with a restart.
- **Config logic in pages:** `scripts/update-uikit` also builds
  `third_party/openp41ge-uikit/config.js`, the config functions alone as a
  plain script (5 KB, not uikit.js's 260 KB), bundled into the app and given
  to the runtime.
- **Runtime:** on a page where content scripts match, it checks the schema
  (`validateConfigSchema`; broken: not run), keeps each stored top-level
  value that fits its schema (`configErrors`; one that doesn't is logged
  and its default used), merges (`configDefaults`, `mergeConfig`), and
  checks the result: a required setting with no value means "needs
  setup", and nothing runs. Secret settings are dropped. Reasons are
  logged to the page's console, prefixed with the extension's name and id.
- **`openp41ge.config.get()`:** the merged settings, a fresh copy each
  call. `onChange` comes with step 5, when something can change settings
  while pages are open; until then values are read when a page is created.
- **Feature toggles:** a content script with a `feature` runs as the user
  set it, else as `enabledByDefault` says.
- **Tests:** features turned on and off by the user; values over defaults,
  an out-of-range value falling back, nested merging, an unknown key kept,
  no secret; needs setup (and a required setting the user set); a default
  that doesn't fit its schema. `runSuite` takes `beforeLaunch(profileDir)`
  to put the user's side in the profile.
- **Example:** `examples/extensions/video-popout` has a `corner` setting.

## Step 5: what was built

- **Scheme** (`src/extensions/extension_scheme.{h,cc}`):
  `openp41ge-extension://<id>/` (standard, secure, fetch), registered in
  every process, served per extension from its folder. A document (main
  frame) only if the manifest's `pages` lists it; never in a frame; any
  file in the folder for what its pages load. Headers: a CSP allowing only
  the extension's own scripts (`script-src 'self'`, no inline ones) and no
  framing, `Cross-Origin-Resource-Policy: same-origin` (web pages can't
  load extension files), `nosniff`, `no-store`.
- **Manifest:** `pages: [{ path, title, role? }]`; `role` is `"settings"`
  (one page at most); the files must exist.
- **API in pages** (`app/extensions/page-runtime.js`), registered in every
  page like the content scripts' runtime but in the page's own world, where
  it does nothing unless the page is the extension's:
  `openp41ge.extension`, `config.get()` (with secrets: the page is the
  extension's own), `values()`, `schema()`, `problems()`, `set(values)`
  (checked against the schema in the page; refused if a value doesn't
  fit), `reset(key)`, `onChange(callback)`, and `openPage(path)` (a new tab
  beside it).
- **Shared settings code:** `app/extensions/settings.js` (reading, fitting,
  dropping secrets) over the code editor's config logic, for both runtimes.
- **Channel:** a second CEF message router (`openp41geExtensionQuery`,
  `src/extensions/extension_router.h`), given by the renderer only to the
  main frame of extension pages; the browser takes a message only from the
  main frame of a loaded extension's page, and only about that extension.
  It never meets the UI's `cefQuery`.
- **Changes:** `config.set` stores the values (`config.json`, written on the
  file thread), registers new scripts in every page (the new ones first,
  then the old removed: a document starting in between runs each runtime
  once), and calls `__openp41geSettingsChanged` in open extension pages and
  in content-script worlds, so `onChange` callbacks run in both
  (`openp41ge.config.onChange` in content scripts too). Content scripts that
  didn't run (setup needed) start from the next page.
- **Late pages:** a page opened by a page (`window.open`) isn't held back
  for the scripts; if it's an extension page it loads again once they're in,
  so its scripts always have `openp41ge`.
- **Not done here:** opening an extension page from a content script
  (`openPage` there needs the content-script channel, step 8); stopping a
  web page from navigating a tab to an extension page (harmless for now:
  settings change only by the page's own code).
- **Tests:** the page opens with the API and without its inline script;
  web pages have neither the channel nor the files; `set` refused for a
  value that doesn't fit, `reset`, then saved, heard by the page and a
  content script (without secrets), in `config.json`, and in the next
  document; `openPage` (and refused for a file that isn't a page); a file
  not in `pages` doesn't open as a page.
- **Example:** `examples/extensions/video-popout` has a settings page.

## Step 6: what was built

- **Where:** `openp41ge-extension://<id>/_openp41ge/settings.html`, for
  every extension: the browser's files (`app/ui/extension-settings`, and
  `_openp41ge/shared/` from `app/ui/shared`) served in the extension's own
  origin, so the page has that extension's `openp41ge` and saves through
  `config.set` like any of its pages; no channel of its own. `_openp41ge/`
  is reserved: a manifest's page can't use it.
- **JSON view:** `<json-editor>` from the bundle (which now also exports
  `pinnedPaths`, `setAt`, `sortJsonKeys`, `cloneDeep` and the overwrite
  event) on the user's values, with the schema (tooltips, suggestions) and
  "Show default values" (defaults faded, "overwrite" pins one), as the code
  editor's `openp41ge-config-editor` does. Edits are staged; Save or Cmd-S;
  a refusal is shown and the edits kept; Revert. A change made elsewhere
  shows while nothing is staged (and is noted when something is).
- **Problems** above the editor: settings that need setting (required, no
  value), a broken schema, and stored values left out because they don't
  fit.
- **Secrets:** left out of the view and its schema; kept as stored when
  saving.
- **Opening it:** by its address for now; the Extensions page (step 10)
  links to it, or to the extension's own `"role": "settings"` page.
- **Tests:** the view shows the user's values without the secret; a
  refused save (message, nothing stored), a saved one (secret kept); a
  change made elsewhere; "needs setting". Edits are made through the
  editor's change event, not typed.

## Step 8: what was built

- **Content scripts' channel:** a DevTools binding per extension
  (`Runtime.addBinding`, named after the extension, with
  `executionContextName` = its world), so only its own world has it and
  the binding's name says which extension sent a message. The browser
  answers by evaluating in the context that sent it. Two things probed
  (2026-10-14): a binding for a named world reaches worlds made later only
  with `Runtime.enable` on (now on in every page with extensions), and even
  then just after the document's first scripts: the runtime looks it up
  when it sends, and a request made before it's there waits up to 1 s.
  `DevToolsClient` passes events on (`OnEvent`).
- **Feature hosts** (`app/extensions/messages.js`, in both runtimes):
  `openp41ge.feature(id)` with `id`, `name`, `enabled`, `broadcast(message)`
  and `onMessage(handler)`, as Internet Utility Belt's `FeatureHost`.
  Messages are JSON. A broadcast goes to the feature's handlers in the
  extension's content scripts in every other tab and in its pages (not the
  tab that sent it), and resolves with their replies; a handler gets 5 s,
  the whole broadcast 6 s.
- **`openp41ge.openPage(path)`** in content scripts too (a tab beside the
  one that asked).
- **Not yet:** `onEnabledChange` (step 10, when features can be switched
  while pages are open).
- **Tests:** a content script's broadcast answered by the other tab and the
  extension's page, not its own; a page's broadcast answered by both tabs;
  an unknown feature; `openPage` from a content script (and refused); the
  binding not in the page's world; a request at document start.

## Step 10: what was built

- **Installed extensions** are remembered in the profile
  (`openp41ge Extensions/installed.json`: `[{ folder, enabled }]`) and load
  at startup; `--extension-folder` adds some for one run ("This run only").
  An installed folder that doesn't load is still listed, with why.
- **The Extensions page,** `openp41ge://extensions/` (`app/ui/extensions`;
  the browser menu's and the Window menu's Extensions): a card per
  extension with its switch, version, description, the sites it runs on
  (in plain words), its features' switches, "Needs setup" (worked out on
  the page with the config logic, from the bundle now in `shared/`),
  Settings (its own settings page, else the browser's), Reload, and Remove
  (asks again on the button; removes its settings too); and Load folder…
  (a native folder picker). Not in private windows. Served with
  `frame-ancestors 'self'`, as all the browser's pages now are.
- **Its channel:** the extension system's (`openp41geExtensionQuery`), which
  the renderer gives this page's main frame too; ExtensionManager checks the
  address. A persistent `listen` gets the list now and after each change.
- **Features switched while pages are open:** the content-script runtime is
  ready in every matching page, whether the features are on or not. On: the
  feature's CSS goes in and its scripts run if they haven't; off: its CSS
  comes out. Either way `feature(id).onEnabledChange` callbacks are told
  (content scripts and extension pages), and later documents are as set.
  A script runs once per document; it tears down and sets up again itself
  (as browser-community's youtube-popout 0.1.1 does).
- **An extension switched on or off, reloaded or removed** changes the
  pages loaded after that (as in Chrome); every page is known to the
  manager, so one added while pages are open reaches them too.
- **The bundle's folders:** the runtime moved to `extension-runtime/`
  (`extensions/` is the page's now), and `uikit.js` to `shared/`.
- **Tests:** the list (installed and this-run badges, sites, features,
  needs setup, a broken one's error); a feature switched on starts in an
  open page, and onEnabledChange off and on; an extension switched off
  isn't in the next page (and `installed.json` says so), and is again when
  switched on; Remove (asks, removes the settings and the installed
  record, gone from the next page); Reload. Load folder… is checked by hand
  (a native dialog).

## Steps

1. ~~**Probe isolated worlds**~~ (done 2026-10-14: they work; see above).
2. ~~**Load a local folder:** manifest, matching, injection, CSS, the
   `openp41ge` API without messages; a fixture extension in the smoke
   tests~~ (done 2026-10-14; see **Step 2: what was built**).
3. ~~**Shared code:** `<json-editor>` and the config logic copied into
   `third_party/openp41ge-uikit/` by `scripts/update-uikit`~~ (done
   2026-10-14).
4. ~~**Settings:** schema in the manifest, user values in the profile,
   merging, `openp41ge.config` in content scripts; feature toggles~~ (done
   2026-10-14; see **Step 4: what was built**).
5. ~~**Extension pages:** the scheme, opening as tabs, `openp41ge.config`
   read and write, change notifications~~ (done 2026-10-14; see **Step 5:
   what was built**).
6. ~~**Settings page, JSON view** with `<json-editor>`~~ (done 2026-10-14;
   see **Step 6: what was built**).
7. **Settings page, form view:** a generic `<json-form>` in
   `openp41ge-sdk-uikit` (code repo), added to the bundle. Handed to an
   agent in the code repo (other work was under way there):
   `plans/2026-10-14-json-form-for-code-repo.md`. The browser's part once
   it's committed: add it to `scripts/uikit/entry.js`, run
   `scripts/update-uikit`, and add the Form view to the settings page.
8. ~~**Feature hosts:** messages between tabs and pages~~ (done
   2026-10-14; see **Step 8: what was built**).
9. ~~**The YouTube pop-out as an extension**~~ (done 2026-10-14, in
   openp41ge/browser-community rather than an Internet Utility Belt build:
   see **The community repo**). Checked by hand on youtube.com
   (`browser-tests/live/youtube-popout.mjs`): the button pops a playing
   video out, and another tab takes the pop-out over through the feature
   host; Shorts pop out with their controls, and the window takes each
   Short's shape. That last needed a browser fix (2026-10-14): a page can't
   move or resize a Document PiP window without a user action, so core.js
   now writes the frame it wants on the pop-out's document
   (`data-openp41ge-frame`), and the pop-out controller places the window
   from it and applies each new one while it's open. Being DOM, it also
   works when an extension's world opened the window: before, the browser
   read the place from the page's main world, missed it, and centred an
   extension's pop-out on the screen.
10. ~~**Extensions page:** list, toggles, settings, load folder, reload,
    remove~~ (done 2026-10-14; see **Step 10: what was built**).
11. **Secrets** in the Keychain.
12. **Install from GitHub:** releases, review, pinning, unpacking checks.
13. **Updates** from GitHub.

Each step comes with smoke tests on local fixture pages and fixture
extensions (no live sites, no live GitHub), run in CI. Settings merging
is `config.ts`'s, tested in the code repo; the browser's tests cover what it
adds: user-provided and required values, values made invalid by an update,
reset, secrets kept out of content scripts and the JSON view.

## Decided

1. The browser has its own extension format; it doesn't emulate Chrome's
   extension APIs.
2. Extensions are plain JS, CSS and HTML; the browser never runs a build.
3. GitHub installs come from release assets, pinned by SHA-256.
4. AI that writes extensions belongs to the openp41ge code editor, not the
   browser.
5. Extension UI outside a page is pages opened as tabs; no overlay popups
   or panels from the browser. In-page UI, modals included, is fine.
6. Settings follow the code editor's config contract: one JSON Schema with
   defaults in the manifest, only user values stored, merged when read
   (`config.ts`); values without a default are user-provided.
7. Settings are edited on a browser-provided page with a form view built
   from the schema and a JSON view (`<json-editor>`), both from the code
   repo's `openp41ge-sdk-uikit`, copied as a built bundle until the UI kit
   gets a repo of its own.
8. The browser's extensions live in openp41ge/browser-community, one per
   feature, in TypeScript built for releases; Internet Utility Belt is
   retired (2026-10-14).
