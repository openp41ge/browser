// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Find in page (src/find_bar.h): the row over the bottom of a pane's page.
// What's typed is found as it's typed; Return (or ↓) goes to the next
// match, Shift+Return (or ↑) to the previous one; Escape (or ✕) closes it.
//
// Messages from the browser: {"type": "open", "text"} (shown, the field
// focused with its text selected), {"type": "result", "count", "active"}.
// To it: {"type": "find", "text", "forward"} (the next match of `text`
// that way: the first as it's typed), {"type": "close"}.

import { listen, send } from './channel.js';

const field = document.getElementById('field');
const count = document.getElementById('count');
const previous = document.getElementById('previous');
const next = document.getElementById('next');

function showResult(matches, active) {
  const found = field.value !== '';
  count.textContent = found ? `${active}/${matches}` : '';
  count.classList.toggle('none', found && matches === 0);
  previous.disabled = next.disabled = !found || matches === 0;
}

function find(forward) {
  send({ type: 'find', text: field.value, forward });
}

field.addEventListener('input', () => {
  showResult(0, 0);
  find(true);
});
field.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    event.preventDefault();
    if (field.value) find(!event.shiftKey);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    send({ type: 'close' });
  }
});
previous.addEventListener('click', () => find(false));
next.addEventListener('click', () => find(true));
document.getElementById('close').addEventListener('click', () => send({ type: 'close' }));

listen((message) => {
  if (message.type === 'open') {
    if (field.value !== message.text) {
      field.value = message.text;
      showResult(0, 0);
    }
    field.focus();
    field.select();
  } else if (message.type === 'result') {
    showResult(message.count, message.active);
  }
});
