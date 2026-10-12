// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The top bar: back, forward and reload for the window's active tab (the
// focused one), its title, a private window's badge, and the menu button.

import { listen, send } from './channel.js';

const $ = (id) => document.getElementById(id);
const back = $('back');
const forward = $('forward');
const reload = $('reload');
const title = $('title');
const menu = $('menu');
const privateBadge = $('private');

function applyState(state) {
  back.disabled = !state.canGoBack;
  forward.disabled = !state.canGoForward;
  title.textContent = state.title;
  title.title = state.title;
  privateBadge.hidden = !state.private;
}

back.addEventListener('click', () => send({ type: 'back' }));
forward.addEventListener('click', () => send({ type: 'forward' }));
// Always reload (a tab shows that its page is loading).
reload.addEventListener('click', () => send({ type: 'reload' }));
// The browser shows the menu (a native one), under the button's right edge.
menu.addEventListener('click', () => {
  const { right, bottom } = menu.getBoundingClientRect();
  send({ type: 'menu', x: Math.round(right), y: Math.round(bottom) });
});

listen((message) => {
  if (message.type === 'state') applyState(message);
});
