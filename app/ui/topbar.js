// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The top bar: back, forward and reload for the window's active tab.

import { listen, send } from './channel.js';

const $ = (id) => document.getElementById(id);
const back = $('back');
const forward = $('forward');
const reload = $('reload');

let loading = false;

function applyState(state) {
  loading = state.loading;
  back.disabled = !state.canGoBack;
  forward.disabled = !state.canGoForward;
  reload.title = loading ? 'Stop' : 'Reload';
  reload.setAttribute('aria-label', reload.title);
  reload.querySelector('.reload-icon').toggleAttribute('hidden', loading);
  reload.querySelector('.stop-icon').toggleAttribute('hidden', !loading);
}

back.addEventListener('click', () => send({ type: 'back' }));
forward.addEventListener('click', () => send({ type: 'forward' }));
reload.addEventListener('click', () => send({ type: loading ? 'stop' : 'reload' }));

listen((message) => {
  if (message.type === 'state') applyState(message);
});
