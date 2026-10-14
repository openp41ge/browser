// Copyright (c) 2026 Richard Kielty. MIT License.
//
// A pane's tab bar: shows the pane's tabs by their sites, activates one
// on click, closes with ✕ (or a middle click), drags tabs (to reorder, to
// another pane, or to a pane's edge to split it), and asks for a new tab
// with +.
//
// A tab's site is its address bar: double-click it to edit the full address
// (selected), Return to go there (or search), Escape or clicking away to
// leave it. Tabs are 220px wide, narrowed to 80% then 60% when that's what
// it takes for them all to fit; past that they scroll. A closed tab shrinks
// away, so it's clear which one went. The filter button
// before "+" opens into a field that shows only the tabs whose site, title
// or headings (the page's h1s) have what's typed.
//
// Resting the pointer on a tab that isn't the active one shows a picture of
// its page under it (taken while it last showed; src/tab_preview.h), fading
// in after a moment, so the pointer can cross the bar without bringing them
// up; while one shows, moving on to another tab shows that one at once. It
// hangs from the bar's bottom edge, the tab's width (following it as tabs
// narrow or scroll), its bottom corners square where it meets the column's
// edges.
//
// As an address is typed, the browser offers pages and sites from history:
// the best one that starts with what's typed completes it inline (the rest
// selected, so typing on replaces it), and they're listed under the tab
// (src/suggestions_popup.h) with a search for what's typed. The arrow keys
// move through them; Tab takes the inline completion; Return or a click
// goes to the one selected.

import { listen, send } from './channel.js';
import { toAddress, toUrl } from './shared/address.js';

const bar = document.querySelector('.bar');
const strip = document.getElementById('tabs');
const filterField = document.getElementById('query');
const fades = { left: document.querySelector('.fade.left'), right: document.querySelector('.fade.right') };

let tabs = [];
let active = -1;
// The filter, while it's open: what's typed, and each tab's page's headings
// (by tab id; the browser sends them).
let filter = null;
// The tab whose address is being edited: { id, field, typed, inline, rows,
// selected } (typed: what was typed, without any inline completion; rows:
// the suggestions shown, if any).
let editing = null;
// The most suggestions listed.
const MAX_ROWS = 7;

// Pages with no address to show (the field shows its placeholder).
const BLANK_PAGES = new Set(['about:blank', 'openp41ge://start/']);

/** What a tab shows of its address: the site (host and port, without www.). */
function displayAddress(url) {
  if (!url || BLANK_PAGES.has(url)) return '';
  try {
    const { protocol, host } = new URL(url);
    if ((protocol === 'https:' || protocol === 'http:') && host) return host.replace(/^www\./, '');
  } catch {}
  return url;
}

// A tab's element, made once and updated in place (so editing survives
// updates while a page loads).
const elements = new Map();

// Material Symbols' "globe" (Apache 2.0), for pages without a favicon.
const DEFAULT_ICON =
  '<svg class="icon" viewBox="0 -960 960 960" aria-hidden="true"><path d="M324-111.5Q251-143 197-197t-85.5-127Q80-397 80-480t31.5-156Q143-709 197-763t127-85.5Q397-880 480-880t156 31.5Q709-817 763-763t85.5 127Q880-563 880-480t-31.5 156Q817-251 763-197t-127 85.5Q563-80 480-80t-156-31.5ZM440-162v-78q-33 0-56.5-23.5T360-320v-40L168-552q-3 18-5.5 36t-2.5 36q0 121 79.5 212T440-162Zm276-102q41-45 62.5-100.5T800-480q0-98-54.5-179T600-776v16q0 33-23.5 56.5T520-680h-80v80q0 17-11.5 28.5T400-560h-80v80h240q17 0 28.5 11.5T600-440v120h40q26 0 47 15.5t29 40.5Z"/></svg>';

function tabElement(tab) {
  let parts = elements.get(tab.id);
  if (!parts) {
    const el = document.createElement('div');
    el.className = 'tab';
    el.dataset.id = tab.id;
    el.setAttribute('role', 'tab');

    // The site's favicon once it has loaded, else a globe.
    const icon = document.createElement('span');
    icon.className = 'icon-slot';
    icon.innerHTML = DEFAULT_ICON;
    // Where ✕ goes: a spinner instead while the page loads (✕ on hover).
    const spinner = document.createElement('span');
    spinner.className = 'spinner';

    const field = document.createElement('input');
    field.className = 'address';
    field.type = 'text';
    field.readOnly = true;
    field.tabIndex = -1;
    field.spellcheck = false;
    field.autocomplete = 'off';
    field.placeholder = 'Search or enter address';
    field.setAttribute('aria-label', 'Address');
    field.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        go(editing?.rows?.[editing.selected]?.url ?? (field.value.trim() && toUrl(field.value)));
      } else if (event.key === 'Escape') {
        event.preventDefault();
        endEdit();
      } else if (event.key === 'Tab' && editing?.field === field) {
        // Accepts the inline completion; never leaves the address.
        event.preventDefault();
        acceptCompletion();
      } else if ((event.key === 'ArrowDown' || event.key === 'ArrowUp') && editing?.rows?.length) {
        event.preventDefault();
        select(editing.selected + (event.key === 'ArrowDown' ? 1 : -1));
      }
    });
    field.addEventListener('input', (event) => {
      if (editing?.field !== field) return;
      editing.typed = field.value;
      // Completed inline only while typing at the end (not after deleting).
      editing.inline = event.inputType?.startsWith('insert') && field.selectionStart === field.value.length;
      if (!editing.typed.trim()) {
        hideSuggestions();
        return;
      }
      send({ type: 'suggest', text: editing.typed });
    });
    field.addEventListener('blur', () => {
      if (editing?.field === field) endEdit();
    });

    const close = document.createElement('button');
    close.className = 'close';
    close.title = 'Close Tab';
    close.setAttribute('aria-label', 'Close Tab');
    close.innerHTML = '<svg viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12" /></svg>';
    close.addEventListener('click', (event) => {
      event.stopPropagation();
      send({ type: 'close', id: Number(el.dataset.id) });
    });

    el.append(icon, field, close, spinner);
    parts = { el, icon, field, favicon: null };
    elements.set(tab.id, parts);
  }

  const { el, icon, field } = parts;
  el.classList.toggle('active', tab.id === active);
  el.setAttribute('aria-selected', String(tab.id === active));
  el.title = BLANK_PAGES.has(tab.url) ? 'New Tab' : tab.url;
  if (editing?.field !== field) field.value = displayAddress(tab.url);

  el.classList.toggle('loading', tab.loading);
  if (parts.favicon !== tab.favicon) {
    parts.favicon = tab.favicon;
    icon.innerHTML = DEFAULT_ICON;
    if (tab.favicon) {
      const img = document.createElement('img');
      img.className = 'icon';
      img.alt = '';
      img.addEventListener('load', () => {
        if (parts.favicon === tab.favicon) icon.replaceChildren(img);
      });
      img.src = tab.favicon;
    }
  }
  return el;
}

function render() {
  const ids = new Set(tabs.map((tab) => tab.id));
  for (const [id, { el }] of elements) {
    if (ids.has(id)) continue;
    if (editing?.id === id) editing = null;
    elements.delete(id);
    shrinkAway(el);
  }
  const els = tabs.map(tabElement);
  // Re-order only if needed: moving an element drops its focus. (Re-ordering
  // drops any tabs still shrinking away.)
  const shown = [...strip.querySelectorAll('.tab')];
  if (els.some((el, i) => shown[i] !== el) || shown.length !== els.length) {
    strip.replaceChildren(...els);
  }
  fit();
  applyFilter();
  // Into view when it changes: otherwise the tabs stay where they've been
  // scrolled to (as others close or load, say).
  if (active !== scrolledTo && !editing) {
    scrolledTo = active;
    strip.querySelector('.tab.active')?.scrollIntoView({ inline: 'nearest' });
  }
  updateFades();
}

// The active tab last scrolled into view.
let scrolledTo = -1;

// --- Closing ---------------------------------------------------------------------

// How long a closed tab takes to shrink away.
const CLOSE_MS = 180;
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');

/**
 * Shrinks a closed tab's element to nothing, then removes it; what it shows
 * stays where it is, cut off by the edge that moves. That's its right edge,
 * the tabs after it following; but with the tabs scrolled to (or near)
 * their end there's nothing to come in from the right, so then its left
 * edge moves instead, the tabs scrolling back: those before it come in from
 * the left and those after it stay put.
 */
function shrinkAway(el) {
  const width = el.offsetWidth;
  if (reduceMotion.matches || el.hidden || !width) {
    el.remove();
    return;
  }
  const fromLeft = strip.scrollLeft > 0 && strip.scrollLeft + strip.clientWidth > strip.scrollWidth - width;
  // Its contents keep their sizes as it narrows (its padding as a margin, so
  // it can narrow past it), and what's shown: ✕ or the spinner, which
  // depend on its hover, which goes.
  for (const child of el.children) {
    child.style.display = getComputedStyle(child).display;
    child.style.width = `${child.offsetWidth}px`;
  }
  el.style.width = `${width}px`;
  // No longer a tab, but looking like one (the one it was).
  el.classList.replace('tab', 'closed-tab');
  el.classList.toggle('from-left', fromLeft);
  el.removeAttribute('role');

  // From the left, its right edge is held where it is by scrolling back as
  // it narrows (by however far it has moved: the browser may have scrolled
  // back some itself, as the tabs got shorter than the scroll).
  const right = el.getBoundingClientRect().right;
  const start = performance.now();
  const step = (now) => {
    if (!el.isConnected) return; // Dropped by a re-order.
    const t = Math.min(1, (now - start) / CLOSE_MS);
    el.style.width = `${width * (1 - t) ** 3}px`; // Easing out.
    if (fromLeft) strip.scrollLeft += el.getBoundingClientRect().right - right;
    if (t < 1) {
      requestAnimationFrame(step);
    } else {
      el.remove();
      // Widened now there's room (the tab took its share until it went).
      fit();
    }
    updateFades();
    reportLayout();
  };
  requestAnimationFrame(step);
}

// --- Widths and the filter ---------------------------------------------------

// A tab's width, and the narrower ones tried (80%, 60%) before they scroll.
const TAB_WIDTHS = [220, 176, 132];
// The filter button and "+", at the right.
const BUTTONS_WIDTH = 68;

/** The widest tabs that all fit (closed ones too, until they've gone); the
 * narrowest (scrolling) if none do. */
function fit() {
  const room = bar.clientWidth - BUTTONS_WIDTH;
  const count = tabs.length + strip.querySelectorAll('.closed-tab').length;
  const width = TAB_WIDTHS.find((w) => count * w <= room) ?? TAB_WIDTHS.at(-1);
  strip.style.setProperty('--tab-width', `${width}px`);
}

function openFilter() {
  if (filter) return;
  filter = { text: '', headings: new Map() };
  bar.classList.add('filtering');
  filterField.tabIndex = 0;
  filterField.focus();
  send({ type: 'headings' });
}

function closeFilter() {
  if (!filter) return;
  filter = null;
  filterField.value = '';
  filterField.tabIndex = -1;
  filterField.blur();
  bar.classList.remove('filtering');
  applyFilter();
  strip.querySelector('.tab.active')?.scrollIntoView({ inline: 'nearest' });
  updateFades();
  reportLayout();
}

/** Whether `tab` has every word typed in its site, title or headings. */
function matchesFilter(tab) {
  const words = filter?.text.toLowerCase().split(/\s+/).filter(Boolean) ?? [];
  if (!words.length) return true;
  let host = '';
  try {
    host = new URL(tab.url).host;
  } catch {}
  const text = [host, tab.title ?? '', ...(filter.headings.get(tab.id) ?? [])].join('\n').toLowerCase();
  return words.every((word) => text.includes(word));
}

function applyFilter() {
  for (const tab of tabs) {
    const parts = elements.get(tab.id);
    if (parts) parts.el.hidden = !matchesFilter(tab);
  }
}

document.getElementById('find').addEventListener('click', () => (filter ? closeFilter() : openFilter()));
filterField.addEventListener('input', () => {
  if (!filter) return;
  filter.text = filterField.value;
  applyFilter();
  strip.scrollLeft = 0;
  updateFades();
  reportLayout();
});
filterField.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    event.preventDefault();
    closeFilter();
  } else if (event.key === 'Enter') {
    // The first tab that matches.
    event.preventDefault();
    const first = strip.querySelector('.tab:not([hidden])');
    if (first) send({ type: 'activate', id: Number(first.dataset.id) });
  }
});
// Clicking away leaves it open only while there's something typed.
filterField.addEventListener('blur', () => {
  if (filter && !filter.text.trim()) closeFilter();
});
addEventListener('resize', () => {
  fit();
  updateFades();
  reportLayout();
});

function startEdit(id) {
  hidePreview();
  const parts = elements.get(id);
  if (!parts) return;
  if (editing?.id === id) return;
  endEdit();
  const tab = tabs.find((t) => t.id === id);
  editing = { id, field: parts.field, typed: '', inline: false, rows: null, selected: 0 };
  parts.el.classList.add('editing');
  parts.field.readOnly = false;
  parts.field.value = tab && !BLANK_PAGES.has(tab.url) ? tab.url : '';
  parts.field.focus();
  parts.field.select();
}

/** Goes to `url` in the tab being edited. */
function go(url) {
  const id = editing?.id;
  endEdit();
  if (url && id !== undefined) send({ type: 'navigate', id, url });
}

// --- Suggestions ---------------------------------------------------------------

/** What was typed, as an address or a search: the row Return takes by default. */
function typedRow(typed) {
  const address = toAddress(typed);
  return address
    ? { kind: 'address', title: typed.trim(), url: address }
    : { kind: 'search', title: typed.trim(), detail: 'Google Search', url: toUrl(typed) };
}

/** The browser's matches for what was typed: complete it inline and list them. */
function showMatches(text, matches) {
  if (!editing || text !== editing.typed) return; // Typed on since.
  const { field, typed } = editing;
  const rows = matches.map((m) => ({ kind: 'history', title: m.title || m.text, detail: m.title ? m.text : '', url: m.url, text: m.text }));
  const top = matches[0];
  // What was typed, without a scheme or "www." (as the matches' text is).
  const bare = typed.replace(/^\s*(https?:\/\/)?(www\.)?/i, '');
  if (editing.inline && top?.completes && !/\s/.test(typed) && top.text.toLowerCase().startsWith(bare.toLowerCase())) {
    field.value = typed + top.text.slice(bare.length);
    field.setSelectionRange(typed.length, field.value.length);
    // The completion first, what was typed (a search, say) last.
    editing.rows = [...rows, typedRow(typed)].slice(0, MAX_ROWS);
  } else {
    editing.rows = [typedRow(typed), ...rows].slice(0, MAX_ROWS);
  }
  editing.selected = 0;
  showSuggestions();
}

/** Takes the inline completion as typed (the caret to its end), and looks again. */
function acceptCompletion() {
  const { field } = editing;
  if (field.selectionStart === field.selectionEnd || field.selectionEnd !== field.value.length) return;
  field.setSelectionRange(field.value.length, field.value.length);
  editing.typed = field.value;
  editing.inline = true;
  send({ type: 'suggest', text: editing.typed });
}

/** Selects row `index`: the address shows it (what was typed, for that row). */
function select(index) {
  const { rows, field } = editing;
  editing.selected = Math.max(0, Math.min(rows.length - 1, index));
  const row = rows[editing.selected];
  field.value = row.text ?? editing.typed;
  field.setSelectionRange(field.value.length, field.value.length);
  showSuggestions();
}

function showSuggestions() {
  const parts = elements.get(editing.id);
  if (!parts) return;
  // Suggestions under the tab: no picture over them.
  hidePreview();
  const r = parts.el.getBoundingClientRect();
  send({
    type: 'suggest-show',
    rows: editing.rows.map(({ kind, title, detail }) => ({ kind, title, detail: detail ?? '' })),
    selected: editing.selected,
    x: Math.round(r.left),
    y: Math.round(r.top),
    width: Math.round(r.width),
    height: Math.round(r.height),
    popupWidth: Math.max(Math.round(r.width), 480),
  });
}

function hideSuggestions() {
  if (!editing?.rows) return;
  editing.rows = null;
  send({ type: 'suggest-hide' });
}

/** Leaves the address as it was. */
function endEdit() {
  const ended = editing;
  if (!ended) return;
  hideSuggestions();
  editing = null;
  const parts = elements.get(ended.id);
  if (!parts) return;
  parts.el.classList.remove('editing');
  parts.field.readOnly = true;
  const tab = tabs.find((t) => t.id === ended.id);
  parts.field.value = displayAddress(tab?.url);
  parts.field.scrollLeft = 0;
  parts.field.blur();
}

function updateFades() {
  fades.left.classList.toggle('shown', strip.scrollLeft > 0);
  fades.right.classList.toggle('shown', strip.scrollLeft + strip.clientWidth < strip.scrollWidth - 1);
}
strip.addEventListener('scroll', updateFades);

// The focus bar's width.
const FOCUS_BAR_WIDTH = 50;

// Where the tabs are, for the window to work out where a dragged tab would
// be inserted (its middle, in this bar's coordinates; a tab the filter hides
// is where the one before it ends); and where the active tab's focus bar
// goes (50px, centred; the part in view), which the window draws over its
// top edge.
function reportLayout() {
  let end = 0;
  const tabs = [...strip.querySelectorAll('.tab')].map((el) => {
    if (el.hidden) return { id: Number(el.dataset.id), middle: Math.round(end) };
    const r = el.getBoundingClientRect();
    end = r.right;
    return { id: Number(el.dataset.id), middle: Math.round(r.left + r.width / 2) };
  });
  const message = { type: 'layout', tabs };
  const active = strip.querySelector('.tab.active:not([hidden])');
  if (active) {
    const r = active.getBoundingClientRect();
    const view = strip.getBoundingClientRect();
    // The middle of the tab less its divider, as it shows.
    const middle = r.left + active.clientWidth / 2;
    const left = Math.max(middle - FOCUS_BAR_WIDTH / 2, view.left);
    const right = Math.min(middle + FOCUS_BAR_WIDTH / 2, view.right);
    if (right > left) message.focusBar = { x: Math.round(left), width: Math.round(right - left) };
  }
  send(message);
}
strip.addEventListener('scroll', reportLayout);

// Click to activate; middle click to close. Dragging (after 3px) moves a
// tab: the window works out where it lands (this bar, another pane's, or a
// pane's edge to split it) from where the pointer is; the mouse stays with
// this bar while the button is down, even outside it.
let drag = null;
strip.addEventListener('mousedown', (event) => {
  const el = event.target.closest('.tab');
  // In the address being edited: placing the caret, selecting.
  if (!el || event.target.closest('.close') || el.classList.contains('editing')) return;
  const id = Number(el.dataset.id);
  if (event.button === 1) {
    event.preventDefault();
    send({ type: 'close', id });
    return;
  }
  if (event.button !== 0) return;
  // The address is only for editing (double-click); the tab takes the press.
  event.preventDefault();
  send({ type: 'activate', id });
  drag = { id, el, startX: event.clientX, startY: event.clientY, moved: false, frame: 0, at: null };
});

addEventListener('mousemove', (event) => {
  if (!drag) return;
  if (!drag.moved && Math.hypot(event.clientX - drag.startX, event.clientY - drag.startY) < 3) return;
  drag.moved = true;
  document.body.style.cursor = 'grabbing';
  drag.el.classList.add('dragging');
  drag.at = { x: Math.round(event.clientX), y: Math.round(event.clientY) };
  // At most once a frame.
  if (drag.frame) return;
  drag.frame = requestAnimationFrame(() => {
    if (!drag) return;
    drag.frame = 0;
    send({ type: 'drag', id: drag.id, ...drag.at });
  });
});

function endDrag() {
  const ended = drag;
  drag = null;
  if (ended.frame) cancelAnimationFrame(ended.frame);
  ended.el.classList.remove('dragging');
  document.body.style.cursor = '';
  showHint(-1);
  return ended;
}

strip.addEventListener('dblclick', (event) => {
  const el = event.target.closest('.tab');
  if (!el || event.target.closest('.close') || el.classList.contains('editing')) return;
  startEdit(Number(el.dataset.id));
});

addEventListener('mouseup', (event) => {
  if (!drag) return;
  const ended = endDrag();
  if (ended.moved) send({ type: 'drop', id: ended.id, x: Math.round(event.clientX), y: Math.round(event.clientY) });
});

addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || !drag) return;
  const ended = endDrag();
  if (ended.moved) send({ type: 'drag-cancel' });
});

// Where a dragged tab would go in this bar (-1: nowhere): a line before tab
// `index` (or after the last).
let hint = null;
function showHint(index) {
  hint?.remove();
  hint = null;
  if (index < 0) return;
  const els = [...strip.querySelectorAll('.tab')];
  if (!els.length) return;
  const x = index < els.length ? els[index].offsetLeft : els.at(-1).offsetLeft + els.at(-1).offsetWidth;
  hint = document.createElement('div');
  hint.className = 'insert';
  hint.style.left = `${x - strip.scrollLeft}px`;
  document.querySelector('.bar').append(hint);
}

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

// --- Previews ------------------------------------------------------------------

// How long the pointer rests on a tab before its picture shows.
const PREVIEW_DELAY_MS = 500;
// The tab whose picture shows (or will, once `timer` fires); and what
// follows its size while it shows.
const preview = {
  id: null,
  timer: 0,
  shown: false,
  watched: null,
  sizer: new ResizeObserver(() => {
    if (preview.shown) showPreview(preview.id);
  }),
};
strip.addEventListener('scroll', () => {
  if (preview.shown) showPreview(preview.id);
});

/** Whether tab `id` gets a picture now: it has one, isn't the active tab,
 * and no tab is being dragged or showing suggestions under it (an address
 * open for typing is fine: a new tab's is). */
function previewable(id) {
  const tab = tabs.find((t) => t.id === id);
  return !!tab?.preview && id !== active && !drag && !editing?.rows;
}

function showPreview(id) {
  const parts = elements.get(id);
  if (!parts) return;
  // The tab as it shows in the bar (a tab scrolled partly out of view: the
  // part in view), down to the bar's bottom edge.
  const r = parts.el.getBoundingClientRect();
  const edges = bar.getBoundingClientRect();
  const left = Math.max(r.left, edges.left);
  const right = Math.min(r.right, edges.right);
  if (right - left < 1) {
    hidePreview();
    return;
  }
  if (preview.watched !== parts.el) {
    preview.sizer.disconnect();
    preview.sizer.observe(parts.el);
    preview.watched = parts.el;
  }
  preview.id = id;
  preview.shown = true;
  // Which tab's picture shows (for the browser's tests).
  document.body.dataset.preview = String(id);
  send({
    type: 'preview-show',
    id,
    x: Math.round(left),
    y: Math.round(r.top),
    width: Math.round(right - left),
    height: Math.round(edges.bottom - r.top),
    squareLeft: left <= edges.left,
    squareRight: right >= edges.right,
  });
}

function hidePreview() {
  clearTimeout(preview.timer);
  preview.timer = 0;
  if (preview.shown) send({ type: 'preview-hide' });
  preview.sizer.disconnect();
  preview.watched = null;
  delete document.body.dataset.preview;
  preview.shown = false;
  preview.id = null;
}

strip.addEventListener('mouseover', (event) => {
  const el = event.target.closest('.tab');
  if (!el) return;
  const id = Number(el.dataset.id);
  // Still on the same tab (moving over its parts).
  if (id === preview.id) return;
  clearTimeout(preview.timer);
  preview.timer = 0;
  if (!previewable(id)) {
    hidePreview();
    return;
  }
  // One showing: this one instead, at once. Else after a rest.
  if (preview.shown) {
    showPreview(id);
    return;
  }
  preview.id = id;
  preview.timer = setTimeout(() => {
    preview.timer = 0;
    if (previewable(id)) showPreview(id);
    else preview.id = null;
  }, PREVIEW_DELAY_MS);
});
strip.addEventListener('mouseout', (event) => {
  // Onto another tab, or another part of this one: mouseover sees to it.
  if (event.relatedTarget?.closest?.('.tab')) return;
  hidePreview();
});
// A press (activating, dragging, closing), the window losing the keyboard.
strip.addEventListener('mousedown', hidePreview, true);
addEventListener('blur', hidePreview);

listen((message) => {
  if (message.type === 'tabs') {
    // While filtering, a page that has finished loading may have new
    // headings: ask again.
    if (filter && message.tabs.some((t) => !t.loading && tabs.find((old) => old.id === t.id)?.loading)) {
      send({ type: 'headings' });
    }
    tabs = message.tabs;
    active = message.active;
    document.body.classList.toggle('focused', message.focused);
    // The tab previewed became the active one, or closed.
    if (preview.id !== null && !previewable(preview.id)) hidePreview();
    render();
    reportLayout();
    // A new tab: its address, ready to type in.
    if (message.edit !== undefined) startEdit(message.edit);
  } else if (message.type === 'suggestions') {
    showMatches(message.text, message.matches);
  } else if (message.type === 'suggestion-picked') {
    const row = editing?.rows?.[message.index];
    if (row) go(row.url);
  } else if (message.type === 'suggestion-removed') {
    // Forgotten, then the suggestions again without it.
    const row = editing?.rows?.[message.index];
    if (row?.kind !== 'history') return;
    send({ type: 'forget', text: row.text });
    // Without any completion or row it was showing.
    const { field, typed } = editing;
    field.value = typed;
    field.setSelectionRange(typed.length, typed.length);
    send({ type: 'suggest', text: editing.typed });
  } else if (message.type === 'headings') {
    if (!filter) return;
    filter.headings.set(message.id, message.headings);
    applyFilter();
    updateFades();
    reportLayout();
  } else if (message.type === 'hint') {
    showHint(message.index);
  }
});
