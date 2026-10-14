2026-10-14

**Status: planned.**

# Extension system

The browser's own extension system, decided 2026-10-13 (Phase 6 of
[PLAN.md](../PLAN.md)). Pages are Alloy style and don't load Chrome
extensions, so site behaviour such as Internet Utility Belt's YouTube and
Shorts pop-out reaches the browser through extensions of the browser's own.
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
  "id": "internet-utility-belt",
  "name": "Internet Utility Belt",
  "version": "0.3.0",
  "description": "Small quality-of-life tools for the web.",
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
    { "path": "guide.html", "title": "Utility Belt guide" }
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
the profile (`Extensions/<id>/config.json`; secrets in the Keychain).
Defaults are never copied into it.

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
  `openp41ge.config.reset(path)`. A page in a site can't change settings.

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

## Internet Utility Belt

Its features are already plain DOM code with `FeatureHost` passed in, so it
needs a new build target:

- An openp41ge entry (`packages/web-extension`) that runs each feature with
  a host made from `openp41ge.feature(id)` instead of `browser.runtime`, and
  uses `openp41ge.popout` instead of bundling `packages/popout`.
- Its settings (`core/settings.ts`) read through a small adapter: WXT
  storage in the WebExtension builds, `openp41ge.config` in this one, with
  the defaults in one JSON Schema both builds use.
- Its toolbar popup isn't needed in the openp41ge build: toggles are on the
  Extensions page and settings on the browser's settings page (the popup
  stays in the other builds).
- A build step that writes the folder above, zipped as a release asset next
  to the Chrome and Firefox builds.

## Installing from GitHub

- **From a release, not the source:** the user gives a repo
  (`owner/repo`, or its URL); the browser lists its releases and installs an
  asset named `*.openp41ge-extension.zip`. It never runs the repo's build.
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
  the profile (`Extensions/`), their manifests, install, update, remove,
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

## Steps

1. ~~**Probe isolated worlds**~~ (done 2026-10-14: they work; see above).
2. **Load a local folder:** manifest, matching, injection, CSS, the
   `openp41ge` API without messages; a fixture extension in the smoke tests.
3. ~~**Shared code:** `<json-editor>` and the config logic copied into
   `third_party/openp41ge-uikit/` by `scripts/update-uikit`~~ (done
   2026-10-14).
4. **Settings:** schema in the manifest, user values in the profile,
   merging, `openp41ge.config` in content scripts; feature toggles.
5. **Extension pages:** the scheme, opening as tabs, `openp41ge.config`
   read and write, change notifications.
6. **Settings page, JSON view** with `<json-editor>`.
7. **Settings page, form view:** a generic `<json-form>` in
   `openp41ge-sdk-uikit` (code repo), added to the bundle.
8. **Feature hosts:** messages between tabs and pages.
9. **Internet Utility Belt's openp41ge build;** YouTube and Shorts pop-out
   checked by hand on live sites (never a test gate).
10. **Extensions page:** list, toggles, settings, load folder, reload,
    remove.
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
