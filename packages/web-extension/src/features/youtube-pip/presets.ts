// YouTube pop-out presets for @openp41ge/popout: how YouTube's players fit
// and behave in the pop-out window.

type Direction = 'up' | 'down';

/** YouTube's player, regular and Shorts: fit it to the pop-out window. */
export const youtubePreset: Openp41gePopout.Preset = {
  id: 'youtube',
  hosts: /(^|\.)youtube\.com$/,
  // Both the regular player and the Shorts player.
  selector: '.html5-video-player',
  // YouTube undoes a bare video.play() on a player it hasn't started:
  // press its own play button.
  play: (el) => {
    if (el.querySelector('video')?.paused) el.querySelector<HTMLElement>('.ytp-play-button')?.click();
  },


  css: `
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
    /* The pop-out window has its own controls (this extension's button
       is styled by the page's content-script CSS, which doesn't reach the
       pop-out window). */
    [data-openp41ge-popout] .utility-belt-pip-button {
      display: none !important;
    }
    /* Theatre mode and fullscreen don't apply to the pop-out. */
    [data-openp41ge-popout] .ytp-size-button,
    [data-openp41ge-popout] .ytp-fullscreen-button {
      display: none !important;
    }
  `,
};

// Material Symbols (viewBox 0 -960 960 960).
const ICONS = {
  up: 'M480-528 296-344l-56-56 240-240 240 240-56 56-184-184Z',
  down: 'M480-344 240-584l56-56 184 184 184-184 56 56-240 240Z',
  autoplay:
    'M380-300v-360l280 180-280 180ZM480-40q-108 0-202.5-49.5T120-228v108H40v-240h240v80h-98q51 75 129.5 117.5T480-120q115 0 208.5-66T820-361l78 18q-45 136-160 219.5T480-40ZM42-520q7-67 32-128.5T143-762l57 57q-32 41-52 87.5T123-520H42Zm214-241-57-57q53-44 114-69.5T440-918v80q-51 5-97 25t-87 52Zm449 0q-41-32-87.5-52T520-838v-80q67 6 128.5 31T762-818l-57 57Zm133 241q-5-51-25-97.5T761-705l57-57q44 52 69 113.5T918-520h-80Z',
};

/**
 * YouTube Shorts. The pop-out holds YouTube's one Shorts player, so moving
 * the feed in the page plays the next Short here. Adds previous/next
 * (stacked at the bottom right), auto-advance (bottom left) and a progress
 * bar along the bottom edge; swipes and the up/down arrow keys move the feed
 * too, and every change of Short slides like the Shorts feed. Moves use
 * YouTube's own navigation buttons.
 */
export const shortsPreset: Openp41gePopout.Preset = {
  id: 'youtube-shorts',
  hosts: /(^|\.)youtube\.com$/,
  appliesTo: (el) => el.id === 'shorts-player' && !!el.querySelector('video'),
  css: `
    .openp41ge-shorts-nav-group, button.openp41ge-auto {
      position: fixed; bottom: 18px; z-index: 2147483647;
    }
    .openp41ge-shorts-nav-group {
      right: 12px; display: flex; flex-direction: column; gap: 8px;
    }
    button.openp41ge-auto { left: 12px; }
    button.openp41ge-shorts-nav { width: 32px; height: 32px; border-radius: 16px; }
    button.openp41ge-shorts-nav svg { width: 22px; height: 22px; }
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
  `,
  setup: ({ el, win, doc, icon, control, keepEventsHere, setAspectRatio }) => {
    const video = el.querySelector('video')!;
    // Listeners on the page's own objects, removed when the pop-out closes.
    const listeners = new AbortController();
    const { signal } = listeners;

    const navGroup = doc.createElement('div');
    navGroup.className = 'openp41ge-shorts-nav-group';
    doc.body.append(navGroup);
    const navControl = (parent: Element, className: string, label: string, d: string, onClick: () => void) =>
      control({
        className: `openp41ge-shorts-nav ${className}`,
        label,
        icon: icon(d, { viewBox: '0 -960 960 960', filled: true }),
        onClick,
        parent,
      });

    // The last frame shown, kept so that whenever the Short changes it can
    // slide away as the next one slides in. Once the page swaps the source
    // the old frame is gone, and changes don't only come from our buttons
    // (YouTube's own auto-scroll, keys or swipes sent to the page), so it's
    // refreshed as the video plays rather than at the moment of the change.
    const lastFrame = doc.createElement('canvas');
    lastFrame.className = 'openp41ge-snap';
    const keepFrame = () => {
      if (video.readyState < 2) return;
      lastFrame.width = video.videoWidth;
      lastFrame.height = video.videoHeight;
      try {
        lastFrame.getContext('2d')?.drawImage(video, 0, 0, lastFrame.width, lastFrame.height);
      } catch {}
    };
    for (const type of ['loadeddata', 'timeupdate', 'seeked']) video.addEventListener(type, keepFrame, { signal });
    keepFrame();

    // Shorts come in different shapes (9:16, 3:4, square…): the window
    // takes each one's, as YouTube's page does. The video fires "resize"
    // whenever its dimensions change.
    const fitWindow = () => {
      if (video.videoWidth && video.videoHeight) setAspectRatio(video.videoWidth / video.videoHeight);
    };
    video.addEventListener('resize', fitWindow, { signal });
    fitWindow();

    // Which way the feed moved: back to a Short seen earlier is up, anything
    // else is down.
    const seen = [location.pathname];
    let current = 0;
    const directionTo = (path: string): Direction | null => {
      if (path === seen[current]) return null;
      const before = seen.lastIndexOf(path, current - 1);
      if (before >= 0) {
        current = before;
        return 'up';
      }
      seen.splice(current + 1, Infinity, path);
      current = seen.length - 1;
      return 'down';
    };

    // Slides the outgoing Short (its last frame) away and the new one in.
    let moving = false;
    const slide = async (direction: Direction | null) => {
      moving = true;
      try {
        doc.body.append(lastFrame);
        // Wait for the next Short's first frame (or give up after 2 s).
        await new Promise<void>((resolve) => {
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
        direction = directionTo(location.pathname) ?? direction;
        if (!direction) return;
        const sign = direction === 'down' ? 1 : -1;
        const timing = { duration: 320, easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)' };
        lastFrame.animate([{ transform: 'translateY(0)' }, { transform: `translateY(${-sign * 100}%)` }], timing);
        await el.animate([{ transform: `translateY(${sign * 100}%)` }, { transform: 'translateY(0)' }], timing).finished;
      } finally {
        lastFrame.remove();
        moving = false;
        keepFrame();
      }
    };

    // Our own moves press YouTube's navigation buttons.
    const go = async (direction: Direction) => {
      const button = document.querySelector<HTMLButtonElement>(`#navigation-button-${direction} button`);
      if (moving || !button || button.disabled) return;
      keepFrame();
      const sliding = slide(direction);
      button.click();
      // The user asked to move on: start the next Short if it loaded paused.
      await sliding;
      if (video.paused) video.play().catch(() => {});
    };

    // Any other change of Short (the page swapping the video's source).
    video.addEventListener(
      'emptied',
      () => {
        if (!moving) slide(null);
      },
      { signal },
    );

    // Up/down arrow keys move the feed, in the pop-out or in the page.
    const onArrow = (event: KeyboardEvent) => {
      if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
      if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;
      const t = event.target;
      if (t instanceof Element && t.closest('input, textarea, select, [contenteditable]:not([contenteditable=false])')) return;
      event.preventDefault();
      event.stopImmediatePropagation();
      go(event.key === 'ArrowUp' ? 'up' : 'down');
    };
    win.addEventListener('keydown', onArrow, true);
    window.addEventListener('keydown', onArrow, { capture: true, signal });

    navControl(navGroup, 'openp41ge-prev', 'Previous Short', ICONS.up, () => go('up'));
    navControl(navGroup, 'openp41ge-next', 'Next Short', ICONS.down, () => go('down'));

    let autoAdvance = false;
    const auto = navControl(doc.body, 'openp41ge-auto', 'Auto-advance', ICONS.autoplay, () => {
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
      const p = video.duration > 0 ? video.currentTime / video.duration : 0;
      fill.style.transform = `scaleX(${Math.min(1, Math.max(0, p))})`;
      if (win.closed) return;
      win.requestAnimationFrame(drawProgress);
    };
    drawProgress();
    const seek = (event: PointerEvent) => {
      if (!(video.duration > 0)) return;
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
    keepEventsHere(progress);

    // Shorts loop instead of ending, so "finished" is the position wrapping
    // back to the start.
    let lastTime = 0;
    video.addEventListener(
      'timeupdate',
      () => {
        const t = video.currentTime;
        if (autoAdvance && !moving && video.duration > 0 && lastTime > video.duration - 1 && t < 1) go('down');
        lastTime = t;
      },
      { signal },
    );
    video.addEventListener('ended', () => autoAdvance && go('down'), { signal });

    // A vertical swipe or wheel moves one Short per gesture. Trackpads send a
    // stream of wheel events (with momentum), so a gesture ends after a
    // short pause. These are handled here, not forwarded to the page.
    let travel = 0;
    let gestureUsed = false;
    let gestureEnd: ReturnType<typeof setTimeout> | undefined;
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

    return () => listeners.abort();
  },
};
