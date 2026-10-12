// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The start page: an ordinary page (no channel to the browser) with a row of
// shortcuts. (Addresses and searches are typed in the tab itself.)
//
// + adds a draft shortcut in the row, its name a text field. As the user
// types, the address is checked (once they pause) and the site's icon fetched;
// a valid draft gets a green ring. Return saves it; Escape or clicking away
// drops it.
//
// Shortcuts are kept in this page's own storage (the profile's site data for
// openp41ge://start). Their icons are the best each site offers, found by the
// browser (icon?url=…, src/ui/site_icon.h).

import { toAddress } from './shared/address.js';

const STORAGE_KEY = 'shortcuts';
// How long typing must pause before the draft's address is checked.
const CHECK_DELAY_MS = 350;

const row = document.getElementById('shortcuts');
const addSlot = document.getElementById('add-slot');
const addButton = document.getElementById('add');

// --- Shortcuts ---------------------------------------------------------------

/** @returns {{name: string, url: string}[]} */
function load() {
  try {
    const list = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '[]');
    return Array.isArray(list) ? list.filter((s) => typeof s?.url === 'string' && typeof s?.name === 'string') : [];
  } catch {
    return [];
  }
}

function save(list) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
}

/** A web address typed for a shortcut, as a URL; null unless it names a host. */
function shortcutUrl(text) {
  const address = toAddress(text);
  if (!address) return null;
  let url;
  try {
    url = new URL(address);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
  const host = url.hostname;
  const isDomain = /^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+([a-z]{2,}|xn--[a-z0-9-]+)$/i.test(host);
  const isLocal = host === 'localhost' || /^\d{1,3}(\.\d{1,3}){3}$/.test(host) || host.startsWith('[');
  return isDomain || isLocal ? url.href : null;
}

/**
 * Loads the site's best icon. Resolves with the image, or null if it has
 * none; stops (and resolves null) if `signal` aborts.
 */
function loadIcon(url, signal) {
  return new Promise((resolve) => {
    const img = new Image();
    img.alt = '';
    const finish = (result) => {
      img.onload = img.onerror = null;
      signal?.removeEventListener('abort', abort);
      resolve(result);
    };
    const abort = () => {
      img.src = '';
      finish(null);
    };
    img.onload = () => finish(img);
    img.onerror = () => finish(null);
    signal?.addEventListener('abort', abort, { once: true });
    img.src = `icon?url=${encodeURIComponent(url)}`;
  });
}

function letterFor(name) {
  const letter = document.createElement('span');
  letter.className = 'letter';
  letter.textContent = name.charAt(0).toUpperCase();
  return letter;
}

const confirmDialog = document.getElementById('confirm-remove');

/**
 * Asks whether to remove `shortcut`, in a modal dialog (Escape or clicking
 * outside it cancels). Resolves true to remove it.
 */
function confirmRemove(shortcut) {
  document.getElementById('confirm-text').textContent = `${shortcut.name} will be removed from your shortcuts.`;
  answer?.(false);
  confirmDialog.returnValue = '';
  confirmDialog.showModal();
  return new Promise((resolve) => (answer = resolve));
}

// Resolves the open question.
let answer = null;
confirmDialog.addEventListener('close', () => {
  // A close event arrives a task after the dialog closes: by then it may
  // have been opened again, for a new question this doesn't answer.
  if (confirmDialog.open || !answer) return;
  const resolve = answer;
  answer = null;
  resolve(confirmDialog.returnValue === 'remove');
});

// A click on the backdrop (the dialog element itself, outside its form).
confirmDialog.addEventListener('click', (event) => {
  if (event.target === confirmDialog) confirmDialog.close('cancel');
});

function render() {
  const items = load().map((shortcut) => {
    const link = document.createElement('a');
    link.className = 'shortcut';
    link.href = shortcut.url;
    link.title = `${shortcut.name}\n${shortcut.url}`;

    const tile = document.createElement('span');
    tile.className = 'tile';
    loadIcon(shortcut.url).then((img) => tile.replaceChildren(img ?? letterFor(shortcut.name)));
    const label = document.createElement('span');
    label.className = 'label';
    label.textContent = shortcut.name;
    link.append(tile, label);

    const remove = document.createElement('button');
    remove.className = 'remove';
    remove.type = 'button';
    remove.title = 'Remove';
    remove.setAttribute('aria-label', `Remove ${shortcut.name}`);
    remove.innerHTML = '<svg viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12" /></svg>';
    remove.addEventListener('click', async () => {
      if (!(await confirmRemove(shortcut))) return;
      // This one, wherever it is now (another tab may have changed the list).
      const list = load();
      const at = list.findIndex((s) => s.url === shortcut.url && s.name === shortcut.name);
      if (at >= 0) list.splice(at, 1);
      save(list);
      render();
    });

    const item = document.createElement('div');
    item.className = 'item';
    item.append(link, remove);
    return item;
  });
  row.replaceChildren(...items, addSlot);
}

// --- Draft shortcut ----------------------------------------------------------

let draft = null;

/** Adds a draft shortcut where + is, its name field focused. */
function startDraft() {
  if (draft) {
    draft.field.focus();
    return;
  }
  const item = document.createElement('div');
  item.className = 'item draft';
  const card = document.createElement('div');
  card.className = 'shortcut';
  const tile = document.createElement('span');
  tile.className = 'tile';
  const field = document.createElement('input');
  field.className = 'label';
  field.type = 'text';
  field.placeholder = 'example.com';
  field.spellcheck = false;
  field.autocomplete = 'off';
  field.setAttribute('aria-label', 'Shortcut address');
  card.append(tile, field);
  item.append(card);
  // Clicking the draft's own tile isn't clicking away.
  card.addEventListener('mousedown', (event) => {
    if (event.target !== field) event.preventDefault();
  });

  draft = { item, tile, field, url: null, timer: 0, check: null };
  row.insertBefore(item, addSlot);
  addSlot.hidden = true;

  field.addEventListener('input', () => {
    // Anything typed since makes earlier checks moot.
    clearTimeout(draft.timer);
    draft.check?.abort();
    draft.check = null;
    draft.url = null;
    item.classList.remove('valid', 'invalid');
    tile.replaceChildren();
    draft.timer = setTimeout(checkDraft, CHECK_DELAY_MS);
  });
  field.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      commitDraft();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      endDraft();
    }
  });
  // Clicking away drops it; switching to another window doesn't.
  field.addEventListener('blur', () => {
    if (document.hasFocus()) endDraft();
  });
  field.focus();
}

/** Checks the draft's address; if it's one, fetches the site's icon. */
function checkDraft() {
  const current = draft;
  if (!current) return;
  clearTimeout(current.timer);
  current.timer = 0;
  const url = shortcutUrl(current.field.value);
  current.url = url;
  current.item.classList.toggle('valid', Boolean(url));
  if (!url) return;
  const check = (current.check = new AbortController());
  loadIcon(url, check.signal).then((img) => {
    if (check.signal.aborted || draft !== current) return;
    current.check = null;
    current.tile.replaceChildren(img ?? letterFor(hostOf(url)));
  });
}

function commitDraft() {
  // Return before the pause: check now.
  if (draft.timer) checkDraft();
  const { url, item } = draft;
  if (!url) {
    item.classList.add('invalid');
    return;
  }
  save([...load(), { name: hostOf(url), url }]);
  endDraft();
  render();
}

/** Drops the draft (nothing of it is kept). */
function endDraft() {
  if (!draft) return;
  const { item, timer, check } = draft;
  draft = null;
  clearTimeout(timer);
  check?.abort();
  item.remove();
  addSlot.hidden = false;
}

addButton.addEventListener('click', startDraft);

render();
