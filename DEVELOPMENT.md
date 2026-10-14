# Developing openp41ge explorer

How the browser is built, released and tested. For what it is and how to
install it, see the [README](README.md); for the design and roadmap, see
[PLAN.md](PLAN.md).

**Pop out:** Window → Pop Out Video (Shift+Cmd+P) moves the page's video
into a frameless window over it; it keeps playing, and closing the window
puts it back. Site-specific pop-outs (such as YouTube's player and Shorts)
come from the [Internet Utility Belt](packages/web-extension) extension.

## Layout

```
app/                    the browser (C++, CEF)
packages/popout/        element pop-out, page side (shared by the browser and the extension)
packages/web-extension/ Internet Utility Belt, a cross-browser extension
```

## Platforms

macOS 12 or later, on Apple Silicon and Intel (releases are universal).

## Building

Requirements: Xcode (command-line tools), CMake 3.21+ and Ninja
(`brew install cmake ninja`).

```sh
scripts/fetch-cef                                    # download the pinned CEF build (see CEF_VERSION)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
open "build/app/Release/openp41ge explorer.app"
```

To try an extension from a folder (its manifest,
`openp41ge-extension.json`, is described in
[plans/2026-10-14-extension-system.md](plans/2026-10-14-extension-system.md)),
e.g. [examples/extensions/video-popout](examples/extensions/video-popout), a
"Pop out" button over the video under the pointer:

```sh
"build/app/Release/openp41ge explorer.app/Contents/MacOS/openp41ge explorer" \
  --extension-folder=examples/extensions/video-popout --enable-logging=stderr --log-level=0
```

Several folders go colon-separated. Quit the app first: launched while it's
running, it hands the address to the open app and the switches are ignored.
The log says whether each extension loaded (`--log-level=0` for the ones
that did), and why not; with `--log-level=0` it also has pages' console
messages, where an extension says why it didn't run (its settings need
setup, or its schema is broken).

Until the settings page exists, an extension's settings and feature
toggles are set by hand, in the profile (`~/Library/Application
Support/openp41ge explorer development/Default/openp41ge Extensions/<id>/`):
`config.json` for settings (only those changed, e.g. `{ "corner":
"bottom-left" }` for the example), `features.json` for features (`{
"<feature id>": false }`). They're read as the app starts.

`third_party/openp41ge-uikit/` is a checked-in copy of parts of the
openp41ge code editor's UI kit (`<json-editor>`, extension config logic),
built from a code worktree by `scripts/update-uikit` (needs `pnpm install`
there). Don't edit it here: change the code repo and run the script again.

macOS asks for the app's Keychain item (Chromium Safe Storage) again after
every build, because each build's ad hoc signature is new. To stop that,
sign local builds with your development certificate, and choose "Always
Allow" once:

```sh
cmake -S . -B build -DEXPLORER_SIGN_IDENTITY="Apple Development"
```

A development build's UI (the top bar, tab bars, menus and start page:
HTML, CSS and JS in `app/ui`) comes straight from this checkout, and
reloads when you save a file there: no build or restart for UI changes.
Changes to `app/src` still need `cmake --build build` and a restart. A
release build, or a development build copied to another machine, uses the
copy in the app bundle.

Pass `--url=<url>` to the app's executable to open a specific page. The
profile (with the start page's saved site icons, in `Site Icons`) lives in
`~/Library/Application Support/openp41ge explorer development` for a local
build, so testing never touches your everyday profile; a release build
(`-DEXPLORER_CHANNEL=release`, as CI builds) uses
`~/Library/Application Support/openp41ge explorer`.

A release build checks for updates daily, with
[Sparkle](https://sparkle-project.org) (run `scripts/fetch-sparkle` first),
and offers what it finds: the top bar's menu button says "Update available"
and its menu starts with the update; nothing installs until the user
accepts. A development build never checks; run it with
`--pretend-update-available=<version>` to see the offer (the tests do). Pass
`--disable-updates` to keep a release build from checking (the tests do).

The app icon is `brand/icon.svg` (a development build shows
`brand/icon-dev.svg`, with hazard tape and a cone). After changing either,
run `scripts/make-icons` (needs Xcode 26) to remake the app's icons in
`app/mac/release` and `app/mac/dev`: an `Assets.car` for macOS 26 and an
`AppIcon.icns` for earlier versions.

## Releases

Builds are published on [GitHub Releases](https://github.com/openp41ge/browser/releases)
as `openp41ge-explorer-<version>-universal.dmg` (one app for Apple Silicon
and Intel Macs), and installed apps offer each new one.

To release, write the release's notes in `release-notes/<version>.md`
(see [its README](release-notes/README.md)), then push a tag `v<version>`
(e.g. `v0.1.0`) on a commit of `master` that has them; [release.yml](.github/workflows/release.yml) does the rest:

1. builds the app for Apple Silicon and Intel, and merges them
   (`scripts/make-universal`)
2. signs it with the Developer ID certificate (`scripts/sign-app`; the
   hardened runtime and the entitlements in `app/mac/entitlements`) and
   has Apple notarize it (`scripts/notarize`)
3. packages it in a signed, notarized disk image (`scripts/make-dmg`, with
   [dmgbuild](https://github.com/dmgbuild/dmgbuild) pinned in
   `app/mac/dmg/requirements.txt`; its window's layout is
   `app/mac/dmg/settings.py` and its background is drawn by
   `app/mac/dmg/background.swift`)
4. waits for `browser-tests` to pass on the commit
5. writes the appcast installed apps check for updates, signed with the
   update key, with the notes for the update dialog to show
   (`scripts/make-appcast`), and publishes the release with the notes, the
   disk image, the appcast and `SHA256SUMS`

Installed apps check
`https://github.com/openp41ge/browser/releases/latest/download/appcast.xml`
daily, so each release must carry its appcast. A tag with a suffix
(`v0.2.0-beta.1`) makes a pre-release, which GitHub's "latest" (and so the
updater) skips.

The workflow needs these repository secrets:

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12` | The Developer ID Application certificate and its key, exported from Keychain Access as a `.p12`, base64-encoded |
| `MACOS_CERT_PASSWORD` | The `.p12`'s password |
| `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID` | For notarizing: the Apple ID, an app-specific password for it (account.apple.com), and the team ID (as `openp41ge/code` uses) |
| `SPARKLE_ED_PRIVATE_KEY` | The update key's private half (`generate_keys -x`); its public half is `EXPLORER_UPDATE_KEY` in `app/CMakeLists.txt` |

## Tests

Tests live in a separate private repository. CI reports their results on every
commit and pull request as the `browser-tests` check.
