// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Element pop-out, page side. Moves a page element into a Document
// Picture-in-Picture window: the same DOM node, with its listeners, state
// and JavaScript context. Closing the window moves it back.
//
// Document PiP is the web's API for moving live elements into another
// window, and Chromium keeps media playing across that move (it reloads
// media moved into any other window). In openp41ge explorer the window is
// frameless and this script can place it (the browser's PiP options for
// every page); in other browsers it's the browser's usual PiP window.
//
// Used by the browser (app bundle, Contents/Resources/popout), which runs
// it in the page's main world, and by Internet Utility Belt
// (packages/web-extension), which runs it in a content script and adds
// site presets (see definePreset below).
//
// Running it defines `globalThis.__openp41ge.popout()` and friends.
// Running it again replaces the functions but keeps the state (the open
// pop-out, the presets).

(() => {
  const op = (globalThis.__openp41ge ??= {});
  op.presets ??= new Map();

  // A preset:
  //   id        unique name
  //   hosts     RegExp for location.hostname the preset is for
  //   selector  the site's element to pop out when none is given (optional)
  //   appliesTo (el) => bool: narrows which popped-out elements it handles
  //   css       extra CSS for the pop-out window (optional)
  //   play      (el) => void: starts the element's media the site's way, for
  //             the `play` option (sites can re-pause a bare media.play())
  //   setup     (ctx) => teardown?: adds behaviour once the element has moved
  //             in; ctx is { el, win, doc, icon, control, keepEventsHere,
  //             setAspectRatio }
  op.definePreset = (preset) => op.presets.set(preset.id, preset);

  const sitePresets = () => [...op.presets.values()].filter((p) => p.hosts.test(location.hostname));

  const CSS = `
    html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
    [data-openp41ge-popout] {
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
    }
    video[data-openp41ge-popout] { object-fit: contain !important; }
    /* The window is frameless: a grab handle centred at the top drags it,
       and a button closes it. Drag regions take clicks even when hidden, so
       the handle is compact rather than full width: it sits clear of the
       element's own controls (e.g. a video's title and top buttons).
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
    button.openp41ge-ctl svg.openp41ge-filled { fill: var(--openp41ge-fg); stroke: none; }
    .openp41ge-visible, .openp41ge-ctl:hover { opacity: 1; }
    /* A window with a frame (browsers other than openp41ge explorer) has its
       own title bar to drag and close it by. */
    .openp41ge-framed .openp41ge-grip, .openp41ge-framed .openp41ge-close { display: none; }
  `;

  // Events the pop-out passes on to the page (see "Complete each event's
  // journey" below).
  const FORWARDED = [
    'mousedown', 'mouseup', 'mousemove', 'click', 'dblclick', 'contextmenu', 'wheel',
    'pointerdown', 'pointerup', 'pointermove', 'pointercancel',
    'touchstart', 'touchmove', 'touchend', 'touchcancel',
    'keydown', 'keyup', 'keypress',
  ];

  const area = (e) => {
    const b = e.getBoundingClientRect();
    return b.width * b.height;
  };
  const isPlaying = (e) =>
    [...e.querySelectorAll('video'), ...(e.matches('video') ? [e] : [])].some((v) => !v.paused);

  // What to pop out: the given selector, else the site preset's, else any
  // video. Pages can have several matches (a YouTube Shorts page also has a
  // hidden 0x0 regular player): take a visible one, preferring one whose
  // video is playing, then the largest.
  const chooseElement = (selector) => {
    selector ||= sitePresets().find((p) => p.selector)?.selector || 'video';
    const candidates = [...document.querySelectorAll(selector)].filter((e) => area(e) > 0);
    return (
      candidates.filter(isPlaying).sort((a, b) => area(b) - area(a))[0] ??
      candidates.sort((a, b) => area(b) - area(a))[0]
    );
  };

  // Whether the page has something to pop out (the browser offers "Play in
  // pop-out" on pages that do).
  op.hasPopoutTarget = (selector) => !!chooseElement(selector);

  // Where the open pop-out is, as [screenX, screenY, width], or null.
  op.popoutPlace = () => {
    const win = op.current?.win;
    return win && !win.closed ? [win.screenX, win.screenY, win.outerWidth] : null;
  };

  // Pops out an element. Options:
  //   element   the element itself, or
  //   selector  CSS selector of the element (default: see chooseElement)
  //   play      start its media after the move (when the user swapped the
  //             pop-out to this page's video)
  //   place     [screenX, screenY, width] to reuse an earlier pop-out's
  //             place; by default it opens right over the element
  // Resolves to 'opened', 'already-open', 'nothing-to-pop-out' or 'refused'.
  op.popout = async ({ element = null, selector = '', play = false, place = null } = {}) => {
    if (op.current) return 'already-open';
    const el = element ?? chooseElement(selector);
    if (!el) return 'nothing-to-pop-out';

    const r = el.getBoundingClientRect();
    // Height over width; the window keeps it while resized.
    let ratio = r.height / r.width;
    const width = Math.round(place ? place[2] : r.width);
    const height = Math.round(width * ratio);
    let win;
    try {
      win = await documentPictureInPicture.requestWindow({ width, height });
    } catch (e) {
      console.warn('[openp41ge] pop-out: could not open the window:', e.name, e.message);
      return 'refused';
    }
    // Where it should go, for browsers that place the window themselves
    // (openp41ge explorer reads this): a previous pop-out's place on screen,
    // or the element's position in this page's viewport.
    op.current = {
      win,
      anchor: place ? { screen: [place[0], place[1]] } : { viewport: [r.left, r.top] },
      size: [width, height],
    };

    // Open right over the element (or where the previous pop-out was).
    const left = place ? place[0] : window.screenX + (window.outerWidth - window.innerWidth) + r.left;
    const top = place ? place[1] : window.screenY + (window.outerHeight - window.innerHeight) + r.top;
    // Chromium lets a PiP window move or resize only on a user action, and
    // opening the window used up this one: where the browser refuses
    // (browsers other than openp41ge explorer), it stays where it opened.
    // requestWindow() already gave it the size.
    const tryTo = (action) => {
      try {
        action();
        return true;
      } catch (e) {
        console.info('[openp41ge] pop-out:', e.message);
        return false;
      }
    };
    // Resizes the pop-out makes itself (not the user's), for a moment after.
    let ownResizeUntil = 0;
    const resizeOwn = (w, h) => {
      ownResizeUntil = performance.now() + 1000;
      tryTo(() => win.resizeTo(w, h));
    };
    // The height the window should have: what it opened at, then whatever
    // the user resizes it to. Shape changes size from this, so a size the
    // browser caps (a wide shape on a small screen) doesn't shrink the next.
    let preferredHeight = height;
    // Browsers that let the page place the window (openp41ge explorer) also
    // make it frameless; others (e.g. Chrome) give it a title bar of their
    // own, to drag and close it by.
    const framed = !tryTo(() => win.moveTo(Math.round(left), Math.round(top)));
    if (win.innerWidth !== width || win.innerHeight !== height) resizeOwn(width, height);

    const presets = sitePresets().filter((p) => !p.appliesTo || p.appliesTo(el));

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
    const style = doc.createElement('style');
    style.textContent = [CSS, ...presets.map((p) => p.css ?? '')].join('\n');
    doc.head.append(style);

    // Start its media while it's still in the page: autoplay rules follow
    // the user's click in this document, not the new window (where it
    // would be paused). Playback carries on through the move.
    if (play) {
      const preset = presets.find((p) => p.play);
      if (preset) {
        preset.play(el);
      } else {
        for (const media of [...el.querySelectorAll('video, audio'), ...(el.matches('video, audio') ? [el] : [])]) {
          media.play().catch(() => {});
        }
      }
    }

    // Move the real element, leaving a placeholder to hold its spot.
    const placeholder = document.createElement('div');
    placeholder.style.cssText = `width:${r.width}px;height:${r.height}px;background:#000`;
    el.replaceWith(placeholder);
    el.setAttribute('data-openp41ge-popout', '');
    doc.body.append(el);

    // Icons rather than characters such as "×", so they're centred exactly.
    // Stroked on a 10x10 grid by default; `filled` for icon sets drawn as
    // shapes (e.g. Material Symbols, viewBox '0 -960 960 960').
    const icon = (d, { viewBox = '0 0 10 10', filled = false } = {}) => {
      const svg = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', viewBox);
      if (filled) svg.classList.add('openp41ge-filled');
      const path = doc.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', d);
      svg.append(path);
      return svg;
    };
    // A button in the shared control style, shown and hidden with the rest.
    const control = ({ className = '', label, icon: svg, onClick, parent = doc.body }) => {
      const b = doc.createElement('button');
      b.className = `openp41ge-ctl ${className}`;
      b.title = label;
      b.setAttribute('aria-label', label);
      b.append(svg);
      b.addEventListener('click', onClick);
      parent.append(b);
      return b;
    };
    // Gives the window a new shape (width / height), e.g. when the element's
    // content changes shape. It keeps its preferred height and stays centred
    // where it is.
    const setAspectRatio = (aspect) => {
      if (!(aspect > 0) || Math.abs(1 / aspect - ratio) < 0.01) return;
      ratio = 1 / aspect;
      const newWidth = Math.round(preferredHeight * aspect);
      tryTo(() => win.moveTo(Math.round(win.screenX + (win.outerWidth - newWidth) / 2), win.screenY));
      resizeOwn(newWidth, preferredHeight);
    };
    // Keeps a control's own input in the pop-out instead of forwarding it.
    const keepEventsHere = (node) => {
      for (const type of FORWARDED) node.addEventListener(type, (event) => event.stopPropagation());
    };

    const grip = doc.createElement('div');
    grip.className = 'openp41ge-ctl openp41ge-grip';
    grip.title = 'Drag to move';
    grip.append(doc.createElement('span'), doc.createElement('span'));
    doc.body.append(grip);
    // Only frameless windows need our handle and close button.
    doc.documentElement.classList.toggle('openp41ge-framed', framed);
    control({ className: 'openp41ge-close', label: 'Put it back', icon: icon('M1 1L9 9M9 1L1 9'), onClick: () => win.close() });

    // Show the controls on any mouse movement and hide them after a pause,
    // like video controls. Over the grab handle the page gets no mouse events
    // at all (the OS treats drag regions as window frame), so the controls
    // stay up while the pointer was last seen on or next to the handle.
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
      for (const c of doc.querySelectorAll('.openp41ge-ctl')) c.classList.remove('openp41ge-visible');
    };
    const showControls = (event) => {
      if (event) lastPointer = { x: event.clientX, y: event.clientY };
      for (const c of doc.querySelectorAll('.openp41ge-ctl')) c.classList.add('openp41ge-visible');
      clearTimeout(hideTimer);
      hideTimer = setTimeout(hideUnlessOnGrip, 2500);
    };
    win.addEventListener('mousemove', showControls, true);
    win.addEventListener('pointerdown', showControls, true);

    const teardowns = [];
    for (const preset of presets) {
      try {
        const teardown = preset.setup?.({ el, win, doc, icon, control, keepEventsHere, setAspectRatio });
        if (teardown) teardowns.push(teardown);
      } catch (e) {
        console.warn(`[openp41ge] pop-out preset ${preset.id} failed:`, e);
      }
    }
    showControls();

    // Keep the window at the element's proportions as it's resized.
    let settle;
    win.addEventListener('resize', () => {
      clearTimeout(settle);
      settle = setTimeout(() => {
        const wanted = Math.round(win.outerWidth * ratio);
        if (performance.now() > ownResizeUntil) preferredHeight = wanted; // The user's resize.
        if (Math.abs(win.outerHeight - wanted) > 1) resizeOwn(win.outerWidth, wanted);
      }, 150);
      // Sites re-measure on window resize.
      window.dispatchEvent(new Event('resize'));
    });

    // Complete each event's journey. Events inside the pop-out bubble up to
    // the pop-out's document and window, but the page's own document-level
    // listeners (drags, press-and-hold, keyboard shortcuts) live on the main
    // document. Once an event has bubbled through the pop-out unhandled, send
    // a copy on to the main document so those listeners see it as if the
    // element had never moved. Coordinates still line up: the element is
    // measured in the pop-out's viewport too.
    const forwarded = new WeakSet();
    for (const type of FORWARDED) {
      win.addEventListener(type, (event) => {
        if (forwarded.has(event)) return;
        // A key the pop-out already handled (e.g. a player toggling on
        // Space) must not reach the page's shortcuts too, or it runs twice.
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

    // While popped out, following a link opens it as a new page instead of
    // navigating this page, so what's popped out keeps running. It's a
    // separate page (`noopener`), which also gives it a document of its own
    // from the start, so the browser's scripts for new pages (the autoplay
    // hold) run in it.
    const openAsNewPage = (event) => {
      if (event.defaultPrevented || event.button !== 0) return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
      if (!link || (link.target && link.target !== '_self')) return;
      const url = new URL(link.href, location.href);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
      event.preventDefault();
      event.stopImmediatePropagation();
      window.open(url.href, '_blank', 'noopener');
    };
    window.addEventListener('click', openAsNewPage, true);
    win.addEventListener('click', openAsNewPage, true);

    win.addEventListener(
      'pagehide',
      () => {
        for (const teardown of teardowns) teardown();
        window.removeEventListener('click', openAsNewPage, true);
        el.removeAttribute('data-openp41ge-popout');
        if (placeholder.isConnected) placeholder.replaceWith(el);
        op.current = null;
        window.dispatchEvent(new Event('resize'));
      },
      { once: true },
    );
    return 'opened';
  };
})();
