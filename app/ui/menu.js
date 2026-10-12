// Copyright (c) 2026 Richard Kielty. MIT License.
//
// A menu, in its own small window (src/menu_window.h): the browser sends
// the items; the page lays them out, says how big it is (the window takes
// that size and shows), and sends the chosen item. Hover or the arrow keys
// pick a row; a click or Return runs it; Escape closes the menu.

import { listen, send } from './channel.js';

const menu = document.getElementById('menu');

const rows = () => [...menu.querySelectorAll('.item:not(:disabled)')];

function show(items) {
  menu.replaceChildren(
    ...items.map((item) => {
      if (item.separator) {
        const line = document.createElement('div');
        line.className = 'separator';
        line.setAttribute('role', 'separator');
        return line;
      }
      const row = document.createElement('button');
      row.className = 'item';
      row.setAttribute('role', 'menuitem');
      row.textContent = item.label;
      row.disabled = !item.enabled;
      row.addEventListener('mousemove', () => row.focus());
      row.addEventListener('mouseleave', () => row.blur());
      row.addEventListener('click', () => send({ type: 'run', id: item.id }));
      return row;
    }),
  );
  const { width, height } = menu.getBoundingClientRect();
  send({ type: 'size', width: Math.ceil(width), height: Math.ceil(height) });
}

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    event.preventDefault();
    send({ type: 'close' });
  } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
    event.preventDefault();
    const all = rows();
    if (!all.length) return;
    const step = event.key === 'ArrowDown' ? 1 : -1;
    const at = all.indexOf(document.activeElement);
    all[at < 0 ? (step > 0 ? 0 : all.length - 1) : (at + step + all.length) % all.length].focus();
  }
});

listen((message) => {
  if (message.type === 'items') show(message.items);
});
