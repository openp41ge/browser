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

macOS on Apple Silicon first.

## Building

Requirements: Xcode (command-line tools), CMake 3.21+ and Ninja
(`brew install cmake ninja`).

```sh
scripts/fetch-cef                                    # download the pinned CEF build (see CEF_VERSION)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
open "build/app/Release/openp41ge explorer.app"
```

Pass `--url=<url>` to the app's executable to open a specific page. The
profile lives in `~/Library/Application Support/openp41ge explorer`.

## Releases

Builds are published on [GitHub Releases](https://github.com/openp41ge/browser/releases)
and update automatically.

## Tests

Tests live in a separate private repository. CI reports their results on every
commit and pull request as the `browser-tests` check.

## License

MIT. See [LICENSE](LICENSE). Parts of `app/` are adapted from CEF's `cefsimple`
sample (BSD-3-Clause, the CEF Authors). CEF and Chromium are distributed under
their own licenses.
