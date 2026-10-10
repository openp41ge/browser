// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_
#define OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_

// Runs in the page's main frame. Toggles the pop-out: moves the element
// matching SELECTOR into a Document Picture-in-Picture window, or closes that
// window (which moves the element back).
//
// Document PiP is the web's API for moving live elements into another
// window: Chromium keeps media playing across the move (it reloads media
// moved into any other window). The browser makes the window frameless and
// lets this script place it (CefBrowserViewDelegate PiP options).
constexpr char kPopoutScript[] = R"JS(
(async () => {
  const SELECTOR = %SELECTOR%;
  // Start the element's media playing after the move (used when the user
  // swaps the pop-out to another page's video).
  const PLAY_AFTER_MOVE = %PLAY%;
  // [screenX, screenY, width] to reuse a previous pop-out's place, or null to
  // open right over the element.
  const PLACE = %PLACE%;

  const FIT_CSS = `
    html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
    [data-openp41ge-popout] {
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
    }
    /* YouTube sizes its player with inline pixel styles. */
    [data-openp41ge-popout] .html5-video-container {
      position: absolute !important;
      inset: 0 !important;
    }
    [data-openp41ge-popout] video {
      position: absolute !important;
      left: 0 !important;
      top: 0 !important;
      width: 100% !important;
      height: 100% !important;
      object-fit: contain !important;
    }
    [data-openp41ge-popout] .ytp-chrome-bottom {
      left: 12px !important;
      width: calc(100% - 24px) !important;
    }
    /* Theatre mode and fullscreen don't apply to the pop-out. */
    [data-openp41ge-popout] .ytp-size-button,
    [data-openp41ge-popout] .ytp-fullscreen-button {
      display: none !important;
    }
    /* The window is frameless: a thin strip along the top edge drags it
       (drag regions take clicks even when invisible, so it stays thin to
       keep clear of the element's own controls), plus a close button. */
    .openp41ge-bar {
      position: fixed; top: 0; left: 0; right: 0; height: 8px;
      z-index: 2147483647;
      background: rgba(255, 255, 255, 0.35);
      -webkit-app-region: drag;
      opacity: 0; transition: opacity 0.2s;
    }
    .openp41ge-close {
      position: fixed; top: 12px; right: 12px; z-index: 2147483647;
      width: 22px; height: 22px; border: 0; border-radius: 11px;
      background: rgba(255, 255, 255, 0.85); color: #000; font: 15px/22px system-ui; cursor: pointer;
      opacity: 0; transition: opacity 0.2s;
    }
    body:hover .openp41ge-bar, body:hover .openp41ge-close { opacity: 1; }
  `;

  const open = window.__openp41gePopout;
  if (open) {
    open.win.close();
    return;
  }

  const el = document.querySelector(SELECTOR);
  if (!el) {
    console.warn('[openp41ge] pop-out: nothing matches', SELECTOR);
    return;
  }

  const r = el.getBoundingClientRect();
  const ratio = r.height / r.width;
  const width = Math.round(PLACE ? PLACE[2] : r.width);
  const height = Math.round(width * ratio);
  let win;
  try {
    win = await documentPictureInPicture.requestWindow({ width, height });
  } catch (e) {
    console.warn('[openp41ge] pop-out: could not open the window:', e.name, e.message);
    return;
  }

  // Open right over the element (or where the previous pop-out was).
  const left = PLACE ? PLACE[0] : window.screenX + (window.outerWidth - window.innerWidth) + r.left;
  const top = PLACE ? PLACE[1] : window.screenY + (window.outerHeight - window.innerHeight) + r.top;
  win.moveTo(Math.round(left), Math.round(top));
  win.resizeTo(width, height);

  // Bring the page's styles along so the element looks the same.
  const doc = win.document;
  doc.title = document.title;
  for (const node of document.querySelectorAll('link[rel~="stylesheet"], style')) {
    doc.head.append(node.cloneNode(true));
  }
  for (const sheet of document.adoptedStyleSheets) {
    const style = doc.createElement('style');
    style.textContent = [...sheet.cssRules].map((rule) => rule.cssText).join('\n');
    doc.head.append(style);
  }
  for (const { name, value } of document.documentElement.attributes) {
    doc.documentElement.setAttribute(name, value);
  }
  const fit = doc.createElement('style');
  fit.textContent = FIT_CSS;
  doc.head.append(fit);

  // Move the real element, leaving a placeholder to hold its spot.
  const placeholder = document.createElement('div');
  placeholder.style.cssText = `width:${r.width}px;height:${r.height}px;background:#000`;
  el.replaceWith(placeholder);
  el.setAttribute('data-openp41ge-popout', '');
  doc.body.append(el);

  const bar = doc.createElement('div');
  bar.className = 'openp41ge-bar';
  const close = doc.createElement('button');
  close.className = 'openp41ge-close';
  close.textContent = '×';
  close.title = 'Put it back';
  close.addEventListener('click', () => win.close());
  doc.body.append(bar, close);

  if (PLAY_AFTER_MOVE) {
    for (const media of [...el.querySelectorAll('video, audio'), ...(el.matches('video, audio') ? [el] : [])]) {
      media.play().catch(() => {});
    }
  }

  // Keep the window at the element's proportions as it's resized.
  let settle;
  win.addEventListener('resize', () => {
    clearTimeout(settle);
    settle = setTimeout(() => {
      const wanted = Math.round(win.outerWidth * ratio);
      if (Math.abs(win.outerHeight - wanted) > 1) win.resizeTo(win.outerWidth, wanted);
    }, 150);
    // Sites (YouTube included) re-measure on window resize.
    window.dispatchEvent(new Event('resize'));
  });

  // Complete each event's journey. Events inside the pop-out bubble up to the
  // pop-out's document and window, but the page's own document-level
  // listeners (drags, press-and-hold, keyboard shortcuts) live on the main
  // document. Once an event has bubbled through the pop-out unhandled, send a
  // copy on to the main document so those listeners see it as if the element
  // had never moved. Coordinates still line up: the element is measured in
  // the pop-out's viewport too.
  const FORWARDED = [
    'mousedown', 'mouseup', 'mousemove', 'click', 'dblclick', 'contextmenu', 'wheel',
    'pointerdown', 'pointerup', 'pointermove', 'pointercancel',
    'touchstart', 'touchmove', 'touchend', 'touchcancel',
    'keydown', 'keyup', 'keypress',
  ];
  const forwarded = new WeakSet();
  for (const type of FORWARDED) {
    win.addEventListener(type, (event) => {
      if (forwarded.has(event)) return;
      // A key the pop-out already handled (e.g. YouTube's player toggling on
      // Space/K) must not reach the page's shortcuts too, or it runs twice.
      // Mouse events are always forwarded: drags depend on them.
      if (event instanceof win.KeyboardEvent && event.defaultPrevented) return;
      const init = {};
      for (const key in event) {
        if (typeof event[key] !== 'function') init[key] = event[key];
      }
      init.view = window;
      const Type = window[event.constructor.name] ?? window.Event;
      const copy = new Type(event.type, init);
      forwarded.add(copy);
      document.dispatchEvent(copy);
    });
  }

  // While popped out, following a link opens it as a new page in the main
  // window instead of navigating this page, so what's playing keeps playing.
  const openAsNewPage = (event) => {
    if (event.defaultPrevented || event.button !== 0) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!link || (link.target && link.target !== '_self')) return;
    const url = new URL(link.href, location.href);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
    event.preventDefault();
    event.stopImmediatePropagation();
    window.open(url.href, 'openp41ge-newpage');
  };
  window.addEventListener('click', openAsNewPage, true);
  win.addEventListener('click', openAsNewPage, true);

  win.addEventListener(
    'pagehide',
    () => {
      window.removeEventListener('click', openAsNewPage, true);
      el.removeAttribute('data-openp41ge-popout');
      if (placeholder.isConnected) placeholder.replaceWith(el);
      window.__openp41gePopout = null;
      window.dispatchEvent(new Event('resize'));
    },
    { once: true },
  );

  window.__openp41gePopout = { win };
})();
)JS";

// Runs before page scripts in pages opened while something is popped out:
// media that tries to start before the user has interacted with the page is
// paused, so it doesn't play over the pop-out.
constexpr char kHoldAutoplayScript[] = R"JS(
window.addEventListener(
  'play',
  (event) => {
    if (!navigator.userActivation.hasBeenActive) event.target.pause();
  },
  true,
);
)JS";

// Where the open pop-out is, as [screenX, screenY, width], or null.
constexpr char kPopoutPlaceScript[] = R"JS(
(() => {
  const win = window.__openp41gePopout?.win;
  return win ? [win.screenX, win.screenY, win.outerWidth] : null;
})()
)JS";

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_
