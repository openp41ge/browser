// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_
#define OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_

// Runs in the page's main frame. Toggles the pop-out: moves the element
// matching SELECTOR into a same-origin child window, or closes that window
// (which moves the element back).
//
// The child window's name carries the element's viewport rect
// ("openp41ge-popout:x,y,w,h") so the browser can create the native window
// right over the element.
constexpr char kPopoutScript[] = R"JS(
(() => {
  const SELECTOR = %SELECTOR%;
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
  const rect = [r.x, r.y, r.width, r.height].map(Math.round).join(',');
  const win = window.open('', `openp41ge-popout:${rect}`);
  if (!win) {
    console.warn('[openp41ge] pop-out: window.open was blocked');
    return;
  }

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

  // Moving media between documents pauses it: remember what was playing so
  // it can carry on after each move.
  const playing = () =>
    [...el.querySelectorAll('video, audio'), ...(el.matches('video, audio') ? [el] : [])]
      .filter((media) => !media.paused);
  const resume = (media) => {
    for (const m of media) if (m.paused) m.play().catch(() => {});
  };
  const wasPlaying = playing();

  // Move the real element, leaving a placeholder to hold its spot.
  const placeholder = document.createElement('div');
  placeholder.style.cssText = `width:${r.width}px;height:${r.height}px;background:#000`;
  el.replaceWith(placeholder);
  el.setAttribute('data-openp41ge-popout', '');
  doc.body.append(el);
  resume(wasPlaying);

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
  // (A same-tab link inside the pop-out would otherwise navigate the pop-out.)
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

  // Sites (YouTube included) re-measure on window resize.
  win.addEventListener('resize', () => window.dispatchEvent(new Event('resize')));

  win.addEventListener(
    'pagehide',
    () => {
      window.removeEventListener('click', openAsNewPage, true);
      el.removeAttribute('data-openp41ge-popout');
      const stillPlaying = playing();
      if (placeholder.isConnected) placeholder.replaceWith(el);
      resume(stillPlaying);
      window.__openp41gePopout = null;
      window.dispatchEvent(new Event('resize'));
    },
    { once: true },
  );

  window.__openp41gePopout = { win };
})();
)JS";

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_
