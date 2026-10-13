# openp41ge explorer

An open-source web browser built on [CEF](https://github.com/chromiumembedded/cef)
(the Chromium Embedded Framework), released alongside
[Openp41ge](https://github.com/openp41ge/app).

Its headline feature is **element pop-out**: show any part of a web page (a
video player, a chat, a dashboard widget) in its own always-on-top window, while
it stays live in its original page and responds to clicks as normal.

> **Status:** early development. See [PLAN.md](PLAN.md) for the design and
> roadmap.

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

macOS asks for the app's Keychain item (Chromium Safe Storage) again after
every build, because each build's ad hoc signature is new. To stop that,
sign local builds with your development certificate, and choose "Always
Allow" once:

```sh
cmake -S . -B build -DEXPLORER_SIGN_IDENTITY="Apple Development"
```

Pass `--url=<url>` to the app's executable to open a specific page. The
profile (with the start page's saved site icons, in `Site Icons`) lives in
`~/Library/Application Support/openp41ge explorer development` for a local
build, so testing never touches your everyday profile; a release build
(`-DEXPLORER_CHANNEL=release`, as CI builds) uses
`~/Library/Application Support/openp41ge explorer`.

A release build also updates itself, with [Sparkle](https://sparkle-project.org)
(run `scripts/fetch-sparkle` first); a development build never does. Pass
`--disable-updates` to keep a release build from checking (the tests do).

The app icon is `brand/icon.svg` (a development build shows
`brand/icon-dev.svg`, with hazard tape and a cone). After changing either,
run `scripts/make-icons` (needs Xcode 26) to remake the app's icons in
`app/mac/release` and `app/mac/dev`: an `Assets.car` for macOS 26 and an
`AppIcon.icns` for earlier versions.

## Releases

Builds are published on [GitHub Releases](https://github.com/openp41ge/browser/releases)
and update automatically. Download the latest from
[the latest release](https://github.com/openp41ge/browser/releases/latest):
`openp41ge-explorer-<version>-universal.dmg` (one app for Apple Silicon and
Intel Macs).

To release, push a tag `v<version>` (e.g. `v0.1.0`) on a commit of
`master`; [release.yml](.github/workflows/release.yml) does the rest:

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
   update key (`scripts/make-appcast`), and publishes the release with the
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

## License

MIT. See [LICENSE](LICENSE). Parts of `app/` are adapted from CEF's `cefsimple`
sample (BSD-3-Clause, the CEF Authors). CEF and Chromium are distributed under
their own licenses.
