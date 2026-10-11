import { defineFeature, type FeatureHost } from '@/core/feature';
import { isDocumentPipSupported, popout } from '@/lib/popout';
import { shortsPreset, youtubePreset } from './presets';

const BUTTON_CLASS = 'utility-belt-pip-button';
/** The icon button among YouTube's own Shorts controls. */
const SHORTS_BUTTON_CLASS = 'utility-belt-pip-shorts-button';
/** On <html> while another tab's video is popped out: the button offers to play this one there. */
const OFFER_CLASS = 'utility-belt-pip-offer';
const SVG_NS = 'http://www.w3.org/2000/svg';
// Material "picture_in_picture_alt".
const ICON_PATH =
  'M19 11h-8v6h8v-6zm4 8V4.98C23 3.88 22.1 3 21 3H3c-1.1 0-2 .88-2 1.98V19c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2zm-2 .02H3V4.97h18v14.05z';

/** Messages between tabs (FeatureHost.broadcast). */
type TabMessage =
  /** Is a video popped out in your tab? Reply: { place } if so. */
  | { type: 'where' }
  /** Close your pop-out so this tab's video can take its place. Reply: { place }. */
  | { type: 'hand-over' };

interface PlaceReply {
  place: Openp41gePopout.Place | null;
}

function isTabMessage(value: unknown): value is TabMessage {
  const type = (value as TabMessage | null)?.type;
  return type === 'where' || type === 'hand-over';
}

function placeOf(replies: unknown[]): PlaceReply | undefined {
  return replies.find((reply): reply is PlaceReply => !!reply && typeof reply === 'object' && 'place' in reply);
}

function report(outcome: string) {
  if (outcome !== 'opened') console.warn('[utility-belt] pop-out:', outcome);
}

async function popOut(player: HTMLElement, host: FeatureHost) {
  if (!isDocumentPipSupported()) {
    // Safari: classic PiP of the bare video, sized by the browser.
    await player.querySelector('video')?.requestPictureInPicture();
    return;
  }
  if (document.documentElement.classList.contains(OFFER_CLASS)) {
    // Another tab's video is popped out: take its place, playing.
    document.documentElement.classList.remove(OFFER_CLASS);
    const current = placeOf(await host.broadcast({ type: 'hand-over' } satisfies TabMessage));
    report(await popout.popout({ element: player, play: true, place: current?.place ?? null }));
    return;
  }
  report(await popout.popout({ element: player }));
}

function createIcon(): SVGSVGElement {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', ICON_PATH);
  svg.append(path);
  return svg;
}

/** Wires a button to pop out the player that `findPlayer` returns. */
function onPress(button: HTMLElement, host: FeatureHost, findPlayer: () => HTMLElement | null) {
  // Keep presses on the button from reaching the player (play/pause, hold-for-2x).
  for (const type of ['pointerdown', 'mousedown', 'dblclick']) {
    button.addEventListener(type, (event) => event.stopPropagation());
  }
  button.addEventListener('click', (event) => {
    event.stopPropagation();
    const player = findPlayer();
    if (player) popOut(player, host).catch((err) => console.warn('[utility-belt] pop-out failed:', err));
  });
}

// Built with DOM APIs, not innerHTML: YouTube enforces Trusted Types.
function createButton(host: FeatureHost): HTMLButtonElement {
  const button = document.createElement('button');
  button.className = BUTTON_CLASS;
  button.title = 'Pop the player out into its own window, right where it is';

  const popOutLabel = document.createElement('span');
  popOutLabel.className = `${BUTTON_CLASS}-label`;
  popOutLabel.textContent = 'Open in picture-in-picture';
  const offerLabel = document.createElement('span');
  offerLabel.className = `${BUTTON_CLASS}-offer-label`;
  offerLabel.textContent = 'Play in pop-out';
  button.append(createIcon(), popOutLabel, offerLabel);
  onPress(button, host, () => button.closest<HTMLElement>('.html5-video-player'));
  return button;
}

/**
 * Shorts: an icon button among YouTube's own controls (before "More
 * actions"), built like them so it looks and sits the same.
 */
function createShortsButton(host: FeatureHost, controls: Element): HTMLElement {
  const wrapper = document.createElement('div');
  wrapper.className = SHORTS_BUTTON_CLASS;
  const button = document.createElement('button');
  button.className = [
    'ytSpecButtonShapeNextHost',
    'ytSpecButtonShapeNextText',
    'ytSpecButtonShapeNextOverlay',
    'ytSpecButtonShapeNextSizeL',
    'ytSpecButtonShapeNextIconButton',
    'ytSpecButtonShapeNextMainstageIconSize',
    'ytSpecButtonShapeNextMainstagePadding',
  ].join(' ');
  button.title = 'Open in picture-in-picture';
  button.setAttribute('aria-label', button.title);
  const icon = document.createElement('div');
  icon.className = 'ytSpecButtonShapeNextIcon';
  icon.setAttribute('aria-hidden', 'true');
  icon.append(createIcon());
  button.append(icon);
  wrapper.append(button);
  // The controls sit beside the Short's player, not inside it.
  onPress(button, host, () =>
    controls.closest('#player-container')?.querySelector<HTMLElement>('#shorts-player') ?? null,
  );
  return wrapper;
}

/** Add the button to every YouTube player (and Shorts control bar) lacking one. */
function addButtons(host: FeatureHost) {
  for (const player of document.querySelectorAll('.html5-video-player:not(#shorts-player)')) {
    if (!player.querySelector(`:scope > .${BUTTON_CLASS}`)) player.append(createButton(host));
  }
  for (const controls of document.querySelectorAll('ytd-shorts-player-controls #right-controls')) {
    if (controls.querySelector(`:scope > .${SHORTS_BUTTON_CLASS}`)) continue;
    const button = createShortsButton(host, controls);
    controls.insertBefore(button, controls.querySelector(':scope > #menu-button'));
  }
}

export const youtubePip = defineFeature({
  id: 'youtube-pip',
  name: 'Pop out YouTube videos',
  description:
    'Adds a button to YouTube players that pops the player out into its own window, right where it is. Shorts get previous/next, auto-advance and a progress bar. While a video is popped out, other YouTube tabs offer to play theirs there instead.',
  isSupported: () => isDocumentPipSupported() || document.pictureInPictureEnabled,
  setup(host) {
    popout.definePreset(youtubePreset);
    popout.definePreset(shortsPreset);

    // YouTube is a single-page app that rebuilds its player, so keep re-adding.
    let scheduled = false;
    const observer = new MutationObserver(() => {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(() => {
        scheduled = false;
        addButtons(host);
      });
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
    addButtons(host);

    // Other tabs ask where this tab's pop-out is, or ask to take it over.
    const stopAnswering = host.onMessage((message) => {
      if (!isTabMessage(message) || !popout.current) return undefined;
      const reply: PlaceReply = { place: popout.popoutPlace() };
      if (message.type === 'hand-over') popout.current.win.close();
      return reply;
    });

    // Offer "Play in pop-out" while another tab's video is popped out.
    const updateOffer = async () => {
      const offer = !popout.current && !!placeOf(await host.broadcast({ type: 'where' } satisfies TabMessage));
      document.documentElement.classList.toggle(OFFER_CLASS, offer);
    };
    const onVisible = () => document.visibilityState === 'visible' && updateOffer();
    document.addEventListener('yt-navigate-finish', updateOffer);
    document.addEventListener('visibilitychange', onVisible);
    updateOffer();

    return () => {
      observer.disconnect();
      stopAnswering();
      document.removeEventListener('yt-navigate-finish', updateOffer);
      document.removeEventListener('visibilitychange', onVisible);
      document.documentElement.classList.remove(OFFER_CLASS);
      for (const button of document.querySelectorAll(`.${BUTTON_CLASS}, .${SHORTS_BUTTON_CLASS}`)) button.remove();
    };
  },
});
