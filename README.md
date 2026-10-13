<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/wordmark-dark.svg">
    <img src="brand/wordmark-light.svg" alt="openp41ge browser" height="56">
  </picture>
</h1>

**openp41ge explorer** is a free, open-source web browser for the Mac, made
by [openp41ge](https://github.com/openp41ge). It runs on Chromium, the same
engine as Google Chrome, so websites work as you'd expect, but there's no
Google sign-in or sync.

## Download

| Platform | Download |
|---|---|
| **macOS** 12 or later, Apple Silicon and Intel | [Latest release](https://github.com/openp41ge/browser/releases/latest): `openp41ge-explorer-<version>-universal.dmg` |
| Windows | Not yet |
| Linux | Not yet |

To install it on a Mac, open the downloaded `.dmg` and drag
**openp41ge explorer** onto **Applications**. After that it keeps itself
up to date: when a new version comes out, it downloads it in the
background and installs it the next time you quit.

> **It's early days.** The browser is in active development, so expect
> missing features and rough edges.

## What it does

- **Pop out a video.** Choose **Window ▸ Pop Out Video** (⇧⌘P) and the
  page's video moves into its own small window that stays on top of your
  other windows. It keeps playing and responds to clicks as normal. Close
  the window and the video goes back into the page.
- **Tabs side by side.** Drag a tab to the left or right edge of a window
  to see two pages next to each other, or drag it into another window.
- **A start page** in every new tab: type an address or a search, or pick
  one of the sites you've added to it.
- **Private windows** (**File ▸ New Private Window**, ⇧⌘N) that keep no
  history and forget everything when you close them.

Coming next: find in page, downloads, bookmarks, and popping out any part
of a page (a chat, a live score, a dashboard), not just videos.

## Questions

**My Mac asks for my password to use "Chromium Safe Storage" in my
keychain.** The browser keeps the key it encrypts your cookies with in your
keychain, under the name Chromium uses. If another Chromium-based app made
that keychain item first, macOS checks with you before sharing it. Enter
your Mac's login password and choose **Always Allow**, and it won't ask
again. A future version will use a keychain item of its own.

**Where are my browsing data and settings?** In
`~/Library/Application Support/openp41ge explorer`.

## For developers

How to build, release and test the browser is in
[DEVELOPMENT.md](DEVELOPMENT.md), and the design and roadmap are in
[PLAN.md](PLAN.md). The browser is written in C++ on
[CEF](https://github.com/chromiumembedded/cef) (the Chromium Embedded
Framework), with its own interface in HTML, CSS and JavaScript.

## License

MIT. See [LICENSE](LICENSE). Parts of `app/` are adapted from CEF's `cefsimple`
sample (BSD-3-Clause, the CEF Authors). CEF and Chromium are distributed under
their own licenses.
