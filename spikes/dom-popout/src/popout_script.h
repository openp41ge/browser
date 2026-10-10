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
    /* The window is frameless: a grab handle centred at the top drags it,
       and a button closes it. Drag regions take clicks even when hidden, so
       the handle is compact rather than full width: it sits clear of the
       element's own controls (e.g. YouTube's title and top buttons).
       All controls share one look (.openp41ge-ctl), following the system's
       light/dark setting. */
    .openp41ge-ctl {
      --openp41ge-bg: rgba(255, 255, 255, 0.92);
      --openp41ge-fg: #1d1d1f;
      --openp41ge-ring: rgba(0, 0, 0, 0.14);
      height: 24px; box-sizing: border-box; padding: 0; border: 0; border-radius: 12px;
      background: var(--openp41ge-bg);
      box-shadow: 0 0 0 1px var(--openp41ge-ring), 0 1px 4px rgba(0, 0, 0, 0.25);
      opacity: 0; transition: opacity 0.2s;
    }
    @media (prefers-color-scheme: dark) {
      .openp41ge-ctl {
        --openp41ge-bg: rgba(44, 44, 46, 0.92);
        --openp41ge-fg: #f5f5f7;
        --openp41ge-ring: rgba(255, 255, 255, 0.16);
      }
    }
    .openp41ge-grip, .openp41ge-close { position: fixed; top: 8px; z-index: 2147483647; }
    .openp41ge-grip {
      left: calc(50% - 70px); width: 140px;
      display: flex; flex-direction: column; justify-content: center; gap: 3px;
      padding: 0 50px;
      cursor: grab;
      -webkit-app-region: drag;
    }
    .openp41ge-grip span {
      display: block; height: 2px; border-radius: 1px; background: var(--openp41ge-fg);
    }
    .openp41ge-close { right: 8px; }
    button.openp41ge-ctl {
      width: 24px;
      display: flex; align-items: center; justify-content: center;
      cursor: pointer;
    }
    button.openp41ge-ctl svg {
      width: 10px; height: 10px; fill: none;
      stroke: var(--openp41ge-fg); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round;
    }
    /* YouTube Shorts: previous above next at the bottom right, auto-advance
       at the bottom left, and a progress bar along the bottom edge. */
    .openp41ge-shorts-nav-group, button.openp41ge-auto {
      position: fixed; bottom: 18px; z-index: 2147483647;
    }
    .openp41ge-shorts-nav-group {
      right: 12px; display: flex; flex-direction: column; gap: 8px;
    }
    button.openp41ge-auto { left: 12px; }
    button.openp41ge-shorts-nav { width: 32px; height: 32px; border-radius: 16px; }
    button.openp41ge-shorts-nav svg { width: 12px; height: 12px; }
    .openp41ge-auto[aria-pressed='true'] { --openp41ge-bg: #0a84ff; --openp41ge-fg: #fff; }
    /* Always visible, thicker under the pointer; click or drag to seek. */
    .openp41ge-progress {
      position: fixed; left: 0; right: 0; bottom: 0; height: 12px; z-index: 2147483647;
      display: flex; align-items: flex-end; cursor: pointer; touch-action: none;
    }
    .openp41ge-progress-track {
      flex: 1; height: 3px; background: rgba(255, 255, 255, 0.3); transition: height 0.15s;
    }
    .openp41ge-progress:hover .openp41ge-progress-track,
    .openp41ge-progress.openp41ge-seeking .openp41ge-progress-track { height: 6px; }
    .openp41ge-progress-fill {
      height: 100%; width: 100%; background: #ff0033;
      transform-origin: left; transform: scaleX(0);
    }
    /* The outgoing Short's last frame, slid away as the next slides in. */
    .openp41ge-snap {
      position: fixed; inset: 0; width: 100vw; height: 100vh; z-index: 2147483646;
      object-fit: contain; background: #000; pointer-events: none;
    }
    .openp41ge-visible, .openp41ge-ctl:hover { opacity: 1; }
  `;

  const open = window.__openp41gePopout;
  if (open) {
    open.win.close();
    return;
  }

  // Pages can have several matches (a YouTube Shorts page also has a
  // hidden 0x0 regular player): take a visible one, preferring the one whose
  // video is playing, then the largest.
  const area = (e) => {
    const b = e.getBoundingClientRect();
    return b.width * b.height;
  };
  const isPlaying = (e) =>
    [...e.querySelectorAll('video'), ...(e.matches('video') ? [e] : [])].some((v) => !v.paused);
  const candidates = [...document.querySelectorAll(SELECTOR)].filter((e) => area(e) > 0);
  const el =
    candidates.filter(isPlaying).sort((a, b) => area(b) - area(a))[0] ??
    candidates.sort((a, b) => area(b) - area(a))[0];
  if (!el) {
    console.warn('[openp41ge] pop-out: nothing visible matches', SELECTOR);
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

  const grip = doc.createElement('div');
  grip.className = 'openp41ge-ctl openp41ge-grip';
  grip.title = 'Drag to move';
  grip.append(doc.createElement('span'), doc.createElement('span'));
  const close = doc.createElement('button');
  close.className = 'openp41ge-ctl openp41ge-close';
  close.title = 'Put it back';
  close.setAttribute('aria-label', 'Put it back');
  // Icons rather than characters such as "×", so they're centred exactly.
  const icon = (d) => {
    const svg = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 10 10');
    const path = doc.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', d);
    svg.append(path);
    return svg;
  };
  close.append(icon('M1 1L9 9M9 1L1 9'));
  close.addEventListener('click', () => win.close());
  doc.body.append(grip, close);

  // Show the controls on any mouse movement and hide them after a pause,
  // like video controls. Over the grab handle the page gets no mouse events
  // at all (the OS treats drag regions as window frame), so the controls
  // stay up while the pointer was last seen on or next to the handle.
  const controls = () => doc.querySelectorAll('.openp41ge-ctl');
  let lastPointer = { x: -1, y: -1 };
  let hideTimer;
  const nearGrip = () => {
    const g = grip.getBoundingClientRect();
    const slack = 8;
    return (
      lastPointer.x >= g.left - slack && lastPointer.x <= g.right + slack &&
      lastPointer.y >= g.top - slack && lastPointer.y <= g.bottom + slack
    );
  };
  const hideUnlessOnGrip = () => {
    if (nearGrip()) {
      hideTimer = setTimeout(hideUnlessOnGrip, 500);
      return;
    }
    for (const c of controls()) c.classList.remove('openp41ge-visible');
  };
  const showControls = (event) => {
    if (event) lastPointer = { x: event.clientX, y: event.clientY };
    for (const c of controls()) c.classList.add('openp41ge-visible');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(hideUnlessOnGrip, 2500);
  };
  win.addEventListener('mousemove', showControls, true);
  win.addEventListener('pointerdown', showControls, true);

  // Events the pop-out passes on to the page (see below).
  const FORWARDED = [
    'mousedown', 'mouseup', 'mousemove', 'click', 'dblclick', 'contextmenu', 'wheel',
    'pointerdown', 'pointerup', 'pointermove', 'pointercancel',
    'touchstart', 'touchmove', 'touchend', 'touchcancel',
    'keydown', 'keyup', 'keypress',
  ];

  // YouTube Shorts: previous / next and auto-advance. The pop-out holds
  // YouTube's one Shorts player, so moving the feed in the page plays the
  // next Short here. Moves use YouTube's own navigation buttons.
  if (el.id === 'shorts-player') {
    const video = el.querySelector('video');
    const navGroup = doc.createElement('div');
    navGroup.className = 'openp41ge-shorts-nav-group';
    doc.body.append(navGroup);
    const navControl = (parent, className, label, d, onClick) => {
      const b = doc.createElement('button');
      b.className = `openp41ge-ctl openp41ge-shorts-nav ${className}`;
      b.title = label;
      b.setAttribute('aria-label', label);
      b.append(icon(d));
      b.addEventListener('click', onClick);
      parent.append(b);
      return b;
    };

    // Moves the feed with YouTube's own navigation buttons, sliding the
    // outgoing Short away as the next one slides in.
    let moving = false;
    const go = async (direction) => {
      const button = document.querySelector(`#navigation-button-${direction} button`);
      if (moving || !button || button.disabled) return;
      moving = true;
      try {
        // Freeze the outgoing frame.
        const snap = doc.createElement('canvas');
        snap.className = 'openp41ge-snap';
        snap.width = video.videoWidth || 1;
        snap.height = video.videoHeight || 1;
        try {
          snap.getContext('2d').drawImage(video, 0, 0, snap.width, snap.height);
        } catch {}
        doc.body.append(snap);

        button.click();
        // Wait for the next Short's first frame (or give up after 2 s).
        await new Promise((resolve) => {
          const done = () => {
            clearTimeout(timer);
            video.removeEventListener('loadeddata', done);
            video.removeEventListener('playing', done);
            resolve();
          };
          const timer = setTimeout(done, 2000);
          video.addEventListener('loadeddata', done);
          video.addEventListener('playing', done);
        });
        // The user asked to move on: start the next Short if it loaded paused.
        if (video.paused) video.play().catch(() => {});

        const sign = direction === 'down' ? 1 : -1;
        const timing = { duration: 320, easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)' };
        snap.animate([{ transform: 'translateY(0)' }, { transform: `translateY(${-sign * 100}%)` }], timing);
        await el.animate([{ transform: `translateY(${sign * 100}%)` }, { transform: 'translateY(0)' }], timing).finished;
        snap.remove();
      } finally {
        moving = false;
      }
    };

    navControl(navGroup, 'openp41ge-prev', 'Previous Short', 'M2 6.5L5 3.5L8 6.5', () => go('up'));
    navControl(navGroup, 'openp41ge-next', 'Next Short', 'M2 3.5L5 6.5L8 3.5', () => go('down'));

    let autoAdvance = false;
    const auto = navControl(doc.body, 'openp41ge-auto', 'Auto-advance', 'M1.5 2.5L5 5L1.5 7.5M5.5 2.5L9 5L5.5 7.5', () => {
      autoAdvance = !autoAdvance;
      auto.setAttribute('aria-pressed', String(autoAdvance));
      auto.title = autoAdvance ? 'Auto-advance: on' : 'Auto-advance: off';
    });
    auto.setAttribute('aria-pressed', 'false');
    auto.title = 'Auto-advance: off';

    // Progress along the bottom edge. Click or drag to seek; these events
    // stay in the pop-out rather than being forwarded to the page.
    const progress = doc.createElement('div');
    progress.className = 'openp41ge-progress';
    const track = doc.createElement('div');
    track.className = 'openp41ge-progress-track';
    const fill = doc.createElement('div');
    fill.className = 'openp41ge-progress-fill';
    track.append(fill);
    progress.append(track);
    doc.body.append(progress);
    const drawProgress = () => {
      const p = video?.duration > 0 ? video.currentTime / video.duration : 0;
      fill.style.transform = `scaleX(${Math.min(1, Math.max(0, p))})`;
      if (win.closed) return;
      win.requestAnimationFrame(drawProgress);
    };
    drawProgress();
    const seek = (event) => {
      if (!(video?.duration > 0)) return;
      const r = track.getBoundingClientRect();
      video.currentTime = (Math.min(Math.max(event.clientX - r.left, 0), r.width) / r.width) * video.duration;
    };
    let seeking = false;
    progress.addEventListener('pointerdown', (event) => {
      seeking = true;
      progress.setPointerCapture(event.pointerId);
      progress.classList.add('openp41ge-seeking');
      seek(event);
    });
    progress.addEventListener('pointermove', (event) => seeking && seek(event));
    const endSeek = () => {
      seeking = false;
      progress.classList.remove('openp41ge-seeking');
    };
    progress.addEventListener('pointerup', endSeek);
    progress.addEventListener('pointercancel', endSeek);
    for (const type of FORWARDED) progress.addEventListener(type, (event) => event.stopPropagation());

    // Shorts loop instead of ending, so "finished" is the position wrapping
    // back to the start.
    let lastTime = 0;
    video?.addEventListener('timeupdate', () => {
      const t = video.currentTime;
      if (autoAdvance && !moving && video.duration > 0 && lastTime > video.duration - 1 && t < 1) go('down');
      lastTime = t;
    });
    video?.addEventListener('ended', () => autoAdvance && go('down'));

    // A vertical swipe or wheel moves one Short per gesture. Trackpads send a
    // stream of wheel events (with momentum), so a gesture ends after a
    // short pause. These are handled here, not forwarded to the page.
    let travel = 0;
    let gestureUsed = false;
    let gestureEnd;
    win.addEventListener(
      'wheel',
      (event) => {
        if (Math.abs(event.deltaY) < Math.abs(event.deltaX)) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        clearTimeout(gestureEnd);
        gestureEnd = setTimeout(() => {
          travel = 0;
          gestureUsed = false;
        }, 250);
        if (gestureUsed) return;
        travel += event.deltaY;
        if (Math.abs(travel) >= 60) {
          gestureUsed = true;
          go(travel > 0 ? 'down' : 'up');
        }
      },
      { capture: true, passive: false },
    );
  }
  showControls();

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
