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

  // Move the real element, leaving a placeholder to hold its spot.
  const placeholder = document.createElement('div');
  placeholder.style.cssText = `width:${r.width}px;height:${r.height}px;background:#000`;
  el.replaceWith(placeholder);
  el.setAttribute('data-openp41ge-popout', '');
  doc.body.append(el);

  // Sites (YouTube included) re-measure on window resize.
  win.addEventListener('resize', () => window.dispatchEvent(new Event('resize')));

  win.addEventListener(
    'pagehide',
    () => {
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

#endif  // OPENP41GE_DOM_POPOUT_SPIKE_POPOUT_SCRIPT_H_
