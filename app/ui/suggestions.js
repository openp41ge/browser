// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Suggestions under a tab's address, in their own small window
// (src/suggestions_popup.h). The tab bar decides the rows and which is
// selected (the keyboard stays there); this draws them, says how tall it is,
// and reports a click, or a click on a history row's ✕ (forget it).

import { listen, send } from './channel.js';

const list = document.getElementById('list');

// Row icons: a clock (a page or site visited), a magnifier (a search), an
// arrow (an address as typed).
const ICONS = {
  history: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><polyline points="12 7 12 12 15 14" /></svg>',
  search: '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></svg>',
  address: '<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg>',
};

// A row's height (suggestions.css), for how many fit.
const ROW_HEIGHT = 32;

function show(rows, selected, { maxHeight, squareLeft, squareRight }) {
  list.classList.toggle('square-left', !!squareLeft);
  list.classList.toggle('square-right', !!squareRight);
  // Whole rows only, above the window's bottom (and its bottom border).
  const fit = Math.max(1, Math.floor(((maxHeight ?? Infinity) - 1) / ROW_HEIGHT));
  list.style.maxHeight = Number.isFinite(fit) ? `${fit * ROW_HEIGHT + 1}px` : '';
  list.replaceChildren(
    ...rows.map((row, index) => {
      const el = document.createElement('div');
      el.className = 'row';
      el.classList.toggle('selected', index === selected);
      el.setAttribute('role', 'option');
      el.setAttribute('aria-selected', String(index === selected));
      el.innerHTML = ICONS[row.kind] ?? ICONS.history;
      const title = document.createElement('span');
      title.className = 'title';
      title.textContent = row.title;
      el.append(title);
      if (row.detail) {
        const detail = document.createElement('span');
        detail.className = 'detail';
        detail.textContent = `— ${row.detail}`;
        el.append(detail);
      }
      if (row.kind === 'history') {
        const remove = document.createElement('button');
        remove.className = 'remove';
        remove.title = 'Remove from history';
        remove.setAttribute('aria-label', 'Remove from history');
        remove.innerHTML = '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18" /></svg>';
        remove.addEventListener('mousedown', (event) => {
          event.preventDefault();
          event.stopPropagation();
          send({ type: 'remove', index });
        });
        el.append(remove);
      }
      // On press, as menus do (and before anything else reacts to the click).
      el.addEventListener('mousedown', (event) => {
        event.preventDefault();
        send({ type: 'pick', index });
      });
      return el;
    }),
  );
  list.querySelector('.row.selected')?.scrollIntoView({ block: 'nearest' });
  send({ type: 'size', height: Math.ceil(list.getBoundingClientRect().height) });
}

listen((message) => {
  if (message.type === 'rows') show(message.rows, message.selected, message);
});
