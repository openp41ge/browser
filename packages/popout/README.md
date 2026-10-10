# @openp41ge/popout

Element pop-out, page side: moves a page element into a Document
Picture-in-Picture window as real DOM (same node, listeners and JavaScript
context), with frameless-window controls, event forwarding back to the
page, and site presets. See the comments in `src/core.js`.

Used by:

- **openp41ge explorer** (`app/`), which bundles `src/` into
  `Contents/Resources/popout` and runs `core.js` in pages for its own
  pop-out command, and `hold-autoplay.js` in pages opened while something
  is popped out.
- **Internet Utility Belt** (`packages/web-extension`), which imports
  `core.js` in its content scripts and adds site presets (YouTube).

Plain scripts with no build step, so the browser can run them as they are.
