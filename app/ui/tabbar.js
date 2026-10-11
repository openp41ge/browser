// Copyright (c) 2026 Richard Kielty. MIT License.
//
// A pane's tab bar: shows the pane's tabs, activates one on click, closes
// with ✕ (or a middle click), reorders by dragging, and asks for a new tab
// with +.

import { listen, send } from './channel.js';

const strip = document.getElementById('tabs');
const fades = { left: document.querySelector('.fade.left'), right: document.querySelector('.fade.right') };

let tabs = [];
let active = -1;

// Pages that show no address in their tab's tooltip.
const BLANK_PAGES = new Set(['about:blank']);

function render() {
  strip.replaceChildren(
    ...tabs.map((tab) => {
      const el = document.createElement('div');
      el.className = `tab${tab.id === active ? ' active' : ''}`;
      el.dataset.id = tab.id;
      el.setAttribute('role', 'tab');
      el.setAttribute('aria-selected', String(tab.id === active));
      el.title = BLANK_PAGES.has(tab.url) ? tab.title || 'New Tab' : `${tab.title}\n${tab.url}`;

      let icon;
      if (tab.loading) {
        icon = document.createElement('span');
        icon.className = 'icon loading';
      } else if (tab.favicon) {
        icon = document.createElement('img');
        icon.className = 'icon';
        icon.src = tab.favicon;
        icon.alt = '';
        icon.addEventListener('error', () => icon.replaceWith(document.createElement('span')));
      }
      const title = document.createElement('span');
      title.className = 'title';
      title.textContent = tab.title || (BLANK_PAGES.has(tab.url) || !tab.url ? 'New Tab' : tab.url);

      const close = document.createElement('button');
      close.className = 'close';
      close.title = 'Close Tab';
      close.setAttribute('aria-label', 'Close Tab');
      close.innerHTML = '<svg viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12" /></svg>';
      close.addEventListener('click', (event) => {
        event.stopPropagation();
        send({ type: 'close', id: tab.id });
      });

      el.append(...(icon ? [icon] : []), title, close);
      return el;
    }),
  );
  strip.querySelector('.tab.active')?.scrollIntoView({ inline: 'nearest' });
  updateFades();
}

function updateFades() {
  fades.left.classList.toggle('shown', strip.scrollLeft > 0);
  fades.right.classList.toggle('shown', strip.scrollLeft + strip.clientWidth < strip.scrollWidth - 1);
}
strip.addEventListener('scroll', updateFades);
addEventListener('resize', updateFades);

// Click to activate; middle click to close; drag to reorder (after 3px).
let drag = null;
strip.addEventListener('mousedown', (event) => {
  const el = event.target.closest('.tab');
  if (!el || event.target.closest('.close')) return;
  const id = Number(el.dataset.id);
  if (event.button === 1) {
    event.preventDefault();
    send({ type: 'close', id });
    return;
  }
  if (event.button !== 0) return;
  if (id !== active) send({ type: 'activate', id });
  drag = { id, el, startX: event.clientX, moved: false, index: -1, line: null };
});

/** Where a tab dropped at clientX would go: before the tab whose middle is past it. */
function insertIndex(x) {
  const els = [...strip.querySelectorAll('.tab')];
  const i = els.findIndex((el) => {
    const r = el.getBoundingClientRect();
    return x < r.left + r.width / 2;
  });
  return i < 0 ? els.length : i;
}

addEventListener('mousemove', (event) => {
  if (!drag) return;
  if (!drag.moved && Math.abs(event.clientX - drag.startX) < 3) return;
  drag.moved = true;
  document.body.style.cursor = 'grabbing';
  drag.el.classList.add('dragging');
  const index = insertIndex(event.clientX);
  const from = tabs.findIndex((t) => t.id === drag.id);
  // Dropping it where it is (either side of itself) changes nothing.
  drag.index = index === from || index === from + 1 ? -1 : index;
  drag.line?.remove();
  drag.line = null;
  if (drag.index < 0) return;
  const els = [...strip.querySelectorAll('.tab')];
  const x = drag.index < els.length ? els[drag.index].offsetLeft : els.at(-1).offsetLeft + els.at(-1).offsetWidth;
  drag.line = document.createElement('div');
  drag.line.className = 'insert';
  drag.line.style.left = `${x - strip.scrollLeft}px`;
  document.querySelector('.bar').append(drag.line);
});

addEventListener('mouseup', () => {
  if (!drag) return;
  const { id, moved, index, line, el } = drag;
  drag = null;
  line?.remove();
  el.classList.remove('dragging');
  document.body.style.cursor = '';
  if (!moved || index < 0) return;
  const from = tabs.findIndex((t) => t.id === id);
  send({ type: 'move', id, index: index > from ? index - 1 : index });
});

// Vertical wheel scrolls the tabs sideways.
strip.addEventListener(
  'wheel',
  (event) => {
    if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return;
    strip.scrollLeft += event.deltaY;
    event.preventDefault();
  },
  { passive: false },
);

document.getElementById('add').addEventListener('click', () => send({ type: 'new-tab' }));

listen((message) => {
  if (message.type !== 'tabs') return;
  tabs = message.tabs;
  active = message.active;
  render();
});
