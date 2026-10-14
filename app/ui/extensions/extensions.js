// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The Extensions page (openp41ge://extensions/): the extensions the browser
// knows, from ExtensionManager, which sends the list now and after every
// change (a persistent "listen" on the extension system's channel,
// `openp41geExtensionQuery`, which only this page and extension pages
// have). For each: its switch, its features' switches, the sites it runs
// on, whether it needs setup, Settings, Reload and Remove; and Load folder…
// See plans/2026-10-14-extension-system.md.

import { configDefaults, configErrors, mergeConfig, validateConfigSchema } from './shared/uikit.js';

const $ = (id) => document.getElementById(id);

/** Sends `message` to the browser; resolves with its answer. */
const send = (message) =>
  new Promise((resolve, reject) =>
    window.openp41geExtensionQuery({
      request: JSON.stringify(message),
      onSuccess: resolve,
      onFailure: (code, text) => reject(new Error(text)),
    }),
  );

const say = (text) => {
  $('message').textContent = text;
  $('message').hidden = !text;
};
const act = (message) => send(message).then(() => say(''), (error) => say(error.message));

/** An element with a class and text. */
const el = (tag, className, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
};

const toggle = (label, checked, onChange) => {
  const input = el('input', 'switch');
  input.type = 'checkbox';
  input.setAttribute('role', 'switch');
  input.setAttribute('aria-label', label);
  input.checked = checked;
  input.addEventListener('change', () => onChange(input.checked));
  return input;
};

/** A match pattern as a site, in plain words. */
const site = (pattern) => {
  if (pattern === '<all_urls>') return 'every site';
  const host = pattern.match(/^[^:]+:\/\/([^/]+)/)?.[1] ?? pattern;
  if (host === '*') return 'every site';
  return host.replace(/^\*\./, '').replace(/:\*$/, '');
};

/** Whether the extension's settings need setting (required, no value). */
const needsSetup = (config) => {
  if (!config) return false;
  try {
    validateConfigSchema(config.schema);
  } catch {
    return false; // A broken schema is the extension's problem, shown on its settings page.
  }
  const each = { type: 'object', properties: config.schema.properties, additionalProperties: config.schema.additionalProperties };
  const fits = Object.fromEntries(
    Object.entries(config.values).filter(([key, value]) => configErrors(each, { [key]: value }).length === 0),
  );
  return configErrors(config.schema, mergeConfig(configDefaults(config.schema), fits)).length > 0;
};

// Remove asks again, on the button, before it removes.
let confirming = null;

function card(extension) {
  const item = el('li', 'card');
  item.dataset.key = extension.key;
  if (!extension.enabled) item.classList.add('off');

  const title = el('div', 'title');
  title.append(el('h2', 'name', extension.name ?? extension.folder.split('/').pop()));
  if (extension.version) title.append(el('span', 'version', extension.version));
  if (!extension.installed) title.append(el('span', 'badge', 'This run only'));
  const setup = !extension.error && needsSetup(extension.config);
  if (setup) title.append(el('span', 'badge attention', 'Needs setup'));
  title.append(
    toggle(`${extension.name ?? 'Extension'} on`, extension.enabled, (on) =>
      act({ type: 'setEnabled', key: extension.key, enabled: on }),
    ),
  );
  item.append(title);

  if (extension.error) {
    item.append(el('p', 'error', `Not loaded: ${extension.error}`));
  } else {
    if (extension.description) item.append(el('p', 'description', extension.description));
    const sites = [...new Set(extension.sites.map(site))];
    if (sites.length) item.append(el('p', 'sites', `Runs on ${sites.join(', ')}`));
    if (extension.features.length) {
      const list = el('ul', 'features');
      for (const feature of extension.features) {
        const row = el('li');
        row.append(
          el('span', '', feature.name),
          toggle(feature.name, feature.enabled, (on) =>
            act({ type: 'setFeature', key: extension.key, feature: feature.id, enabled: on }),
          ),
        );
        list.append(row);
      }
      item.append(list);
    }
  }
  item.append(el('p', 'folder', extension.folder));

  const actions = el('div', 'actions');
  if (extension.settings && extension.enabled && !extension.error) {
    const settings = el('button', '', 'Settings');
    settings.addEventListener('click', () => act({ type: 'openSettings', key: extension.key }));
    actions.append(settings);
  }
  const reload = el('button', '', 'Reload');
  reload.title = 'Read its folder again (pages loaded from now on get it)';
  reload.addEventListener('click', () => act({ type: 'reload', key: extension.key }));
  const remove = el('button', 'danger', confirming === extension.key ? 'Remove, and its settings?' : 'Remove');
  remove.addEventListener('click', () => {
    if (confirming !== extension.key) {
      confirming = extension.key;
      remove.textContent = 'Remove, and its settings?';
      return;
    }
    confirming = null;
    act({ type: 'remove', key: extension.key });
  });
  remove.addEventListener('blur', () => {
    if (confirming === extension.key) {
      confirming = null;
      remove.textContent = 'Remove';
    }
  });
  actions.append(reload, remove);
  item.append(actions);
  return item;
}

function show(extensions) {
  $('list').replaceChildren(...extensions.map(card));
  $('empty').hidden = extensions.length > 0;
  document.body.dataset.ready = 'true';
}

$('load').addEventListener('click', () => act({ type: 'loadFolder' }));

window.openp41geExtensionQuery({
  request: JSON.stringify({ type: 'listen' }),
  persistent: true,
  onSuccess: (response) => show(JSON.parse(response)),
  onFailure: (code, text) => say(text),
});
