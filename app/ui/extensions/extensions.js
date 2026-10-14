// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The Extensions page (openp41ge://extensions/): the extensions the browser
// knows, from ExtensionManager, which sends the list now and after every
// change (a persistent "listen" on the extension system's channel,
// `openp41geExtensionQuery`, which only this page and extension pages
// have). For each: its switch, its features' switches, the sites it runs
// on, whether it needs setup, Settings, Reload and Remove; Load folder…;
// and Install from GitHub…: a repo's extensions (from its releases), then a
// review of the one chosen (downloaded, checked and unpacked by the
// browser, but not installed until the user accepts), then Install; and
// updates: Check for updates (also when the page opens, at most hourly)
// marks the GitHub ones with a newer release, and Update installs it (one
// that would run on new sites asks first).
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
  if (extension.update) title.append(el('span', 'badge update', `Update to ${extension.update.version}`));
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
  item.append(
    el('p', 'folder', extension.github ? `From github.com/${extension.github.repo} (${extension.github.tag})` : extension.folder),
  );

  const actions = el('div', 'actions');
  if (extension.settings && extension.enabled && !extension.error) {
    const settings = el('button', '', 'Settings');
    settings.addEventListener('click', () => act({ type: 'openSettings', key: extension.key }));
    actions.append(settings);
  }
  if (extension.update && !extension.error) {
    const update = el('button', 'primary', 'Update');
    update.addEventListener('click', () => updateExtension(extension, item, update));
    actions.append(update);
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

$('check').addEventListener('click', async () => {
  $('check').disabled = true;
  try {
    const found = Number(await send({ type: 'githubCheck' }));
    say('');
    $('check').textContent = found ? `${found} update${found === 1 ? '' : 's'}` : 'Up to date';
    setTimeout(() => ($('check').textContent = 'Check for updates'), 3000);
  } catch (error) {
    say(error.message);
  } finally {
    $('check').disabled = false;
  }
});

/** Updates `extension`: straight away, or after asking if it would run on new sites. */
async function updateExtension(extension, item, button) {
  button.disabled = true;
  button.textContent = 'Downloading…';
  let details;
  try {
    details = JSON.parse(await send({ type: 'githubUpdate', key: extension.key }));
  } catch (error) {
    say(error.message);
    button.disabled = false;
    button.textContent = 'Update';
    return;
  }
  const install = () =>
    send({ type: 'githubInstall', token: details.token }).then(
      () => say(''),
      (error) => say(error.message),
    );
  if (!details.newSites.length) {
    install();
    return;
  }
  // It would run on sites it doesn't now: the user says.
  const sites = [...new Set(details.newSites.map(site))];
  const box = el('div', 'update-review');
  box.append(el('p', '', `${details.name} ${details.version} would also run on ${sites.join(', ')}.`));
  const accept = el('button', 'primary', `Update to ${details.version}`);
  const cancel = el('button', '', 'Not now');
  accept.addEventListener('click', install);
  cancel.addEventListener('click', () => {
    send({ type: 'githubCancel', token: details.token }).catch(() => {});
    box.remove();
    button.disabled = false;
    button.textContent = 'Update';
  });
  const actions = el('div', 'actions');
  actions.append(accept, cancel);
  box.append(actions);
  item.append(box);
}

// Install from GitHub.
let reviewing = null; // The token of the release being reviewed.
const installStatus = (text, error = false) => {
  $('install-status').textContent = text;
  $('install-status').classList.toggle('error', error);
};
const cancelReview = () => {
  if (reviewing) send({ type: 'githubCancel', token: reviewing }).catch(() => {});
  reviewing = null;
  $('review').hidden = true;
  $('review').replaceChildren();
};
const closeInstall = () => {
  cancelReview();
  $('install').hidden = true;
  $('found').replaceChildren();
  installStatus('');
};
$('github').addEventListener('click', () => {
  $('install').hidden = false;
  $('repo').focus();
});
$('close-install').addEventListener('click', closeInstall);

$('find').addEventListener('submit', async (event) => {
  event.preventDefault();
  cancelReview();
  $('found').replaceChildren();
  installStatus('Looking for extensions…');
  try {
    const { repo, extensions } = JSON.parse(await send({ type: 'githubFind', repo: $('repo').value }));
    installStatus(`${extensions.length === 1 ? 'An extension' : `${extensions.length} extensions`} in ${repo}:`);
    $('found').replaceChildren(
      ...extensions.map((found) => {
        const row = el('li');
        const choose = el('button', '', 'Review…');
        choose.addEventListener('click', () => review(repo, found));
        row.append(el('span', '', `${found.id} ${found.version}`), choose);
        return row;
      }),
    );
  } catch (error) {
    installStatus(error.message, true);
  }
});

/** The settings an extension will ask for: required ones without a default, and secrets. */
const asksFor = (config) =>
  Object.entries(config?.properties ?? {})
    .filter(([key, s]) => s.secret === true || ((config.required ?? []).includes(key) && s.default === undefined))
    .map(([key, s]) => `${s.title ?? key}${s.secret === true ? ' (secret)' : ''}`);

async function review(repo, found) {
  cancelReview();
  installStatus(`Downloading ${found.id} ${found.version}…`);
  let details;
  try {
    details = JSON.parse(await send({ type: 'githubPrepare', repo, id: found.id }));
  } catch (error) {
    installStatus(error.message, true);
    return;
  }
  reviewing = details.token;
  installStatus('Review it before installing: nothing runs until you install it.');
  const sites = [...new Set(details.sites.map(site))];
  const settings = asksFor(details.config);
  const rows = [
    ['Version', details.version],
    ['From', `github.com/${details.repo}, release ${details.tag}`],
    ['Runs on', sites.length ? sites.join(', ') : 'no sites (its own pages only)'],
    ...(details.features.length ? [['Features', details.features.join(', ')]] : []),
    ...(settings.length ? [['Asks for', settings.join(', ')]] : []),
    ['SHA-256', details.sha256],
  ];
  const list = el('dl');
  for (const [term, value] of rows) list.append(el('dt', '', term), el('dd', '', value));
  const install = el('button', 'primary', `Install ${details.name}`);
  const cancel = el('button', '', 'Cancel');
  cancel.addEventListener('click', () => {
    cancelReview();
    installStatus('');
  });
  install.addEventListener('click', async () => {
    const token = reviewing;
    reviewing = null;
    try {
      const key = JSON.parse(await send({ type: 'githubInstall', token }));
      closeInstall();
      // Setup first, if it asks for settings it can't run without.
      if (settings.length) act({ type: 'openSettings', key });
    } catch (error) {
      installStatus(error.message, true);
    }
  });
  const actions = el('div', 'actions');
  actions.append(install, cancel);
  $('review').replaceChildren(el('h3', '', details.name), ...(details.description ? [el('p', 'description', details.description)] : []), list, actions);
  $('review').hidden = false;
}

window.openp41geExtensionQuery({
  request: JSON.stringify({ type: 'listen' }),
  persistent: true,
  onSuccess: (response) => show(JSON.parse(response)),
  onFailure: (code, text) => say(text),
});
