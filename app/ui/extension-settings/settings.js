// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The browser's settings page for an extension, served in the extension's
// own origin at openp41ge-extension://<id>/_openp41ge/settings.html
// (src/extensions/extension_scheme.cc), so it has the extension's
// `openp41ge` (app/extensions/page-runtime.js) and changes its settings as
// any of its pages can. See plans/2026-10-14-extension-system.md, "Editing
// settings".
//
// Two views of the same staged values, as the code editor's config editor
// has. It opens in the Form view: the code editor's <json-form>, a field per
// setting from the schema (defaults faded until set, Reset, the schema's
// problems with the values under their fields; objects and lists open in
// drawers over the page). The "JSON view" toggle switches to <json-editor>
// on the user's values (only what they set), with the schema (key tooltips
// and suggestions) and, with "Show default values", the defaults shown
// faded. Edits are staged until Save (or Cmd-S); a refusal is
// shown and the edits kept. While nothing is staged, a change made elsewhere
// (another of the extension's pages) is shown. Secret settings are left out
// of this view, and kept as stored when saving: they have a section of their
// own above it (a masked field each, Save and Clear; kept in the Keychain by
// the browser). Above those: the settings that need setting (required, with
// no value) and the stored values left out because they don't fit the
// schema.

import {
  cloneDeep,
  configDefaults,
  configErrors,
  mergeConfig,
  mergeDefaults,
  pinnedPaths,
  setAt,
  sortJsonKeys,
  stripDefaults,
} from './shared/uikit.js';

const api = window.openp41ge;
const $ = (id) => document.getElementById(id);

const note = (text) => {
  $('note').textContent = text;
  $('note').hidden = false;
};

if (!api) {
  note('This page only works in an extension.');
} else {
  start();
}

function start() {
  const { name, version } = api.extension;
  document.title = `${name} settings`;
  $('title').textContent = name;
  $('version').textContent = `Settings · ${version}`;

  const schema = api.config.schema();
  if (!Object.keys(schema.properties ?? {}).length) {
    note(`${name} has no settings.`);
    return;
  }
  const secret = new Set(Object.entries(schema.properties).filter(([, s]) => s.secret === true).map(([key]) => key));
  // The schema and defaults the view shows: without the secrets.
  const shownSchema = { ...schema, properties: Object.fromEntries(Object.entries(schema.properties).filter(([key]) => !secret.has(key))) };
  shownSchema.required = (schema.required ?? []).filter((key) => !secret.has(key));
  let defaults = {};
  try {
    defaults = sortJsonKeys(configDefaults(shownSchema));
  } catch {
    // A broken schema: shown as a problem below.
  }
  const shown = (values) => Object.fromEntries(Object.entries(values).filter(([key]) => !secret.has(key)));

  // The stored values (the baseline), and the staged ones.
  let saved = shown(api.config.values());
  let staged = cloneDeep(saved);
  let pinned = pinnedPaths(staged, defaults);
  let showDefaults = false;
  let jsonView = false;
  let saving = false;

  const form = document.createElement('json-form');
  form.schema = shownSchema;
  form.defaults = defaults;
  // Its drawers cover the whole page.
  form.drawerArea = document.body;
  const editor = document.createElement('json-editor');
  editor.schema = shownSchema;
  editor.defaults = defaults;
  $('editor-area').append(form, editor);
  $('bar').hidden = false;

  // The schema's problems with the staged values over the defaults (what
  // Save checks), by path (`a.b[0]`).
  const formErrors = () => {
    try {
      return configErrors(shownSchema, mergeConfig(defaults, staged)).map((message) => {
        const at = message.indexOf(': ');
        return { path: at > 0 ? message.slice(0, at) : '', message };
      });
    } catch {
      return [];
    }
  };

  const dirty = () => JSON.stringify(sortJsonKeys(staged)) !== JSON.stringify(sortJsonKeys(saved));
  const status = (text, error = false) => {
    $('status').textContent = text;
    $('status').classList.toggle('error', error);
  };
  const render = () => {
    form.hidden = jsonView;
    editor.hidden = !jsonView;
    $('show-defaults-toggle').hidden = !jsonView;
    if (jsonView) {
      editor.value = showDefaults ? mergeDefaults(staged, defaults) : staged;
      editor.showDefaults = showDefaults;
      editor.explicitPaths = [...pinned];
    } else {
      form.value = staged;
      form.errors = formErrors();
    }
    buttons();
  };
  const buttons = () => {
    $('save').disabled = saving || !dirty();
    $('revert').disabled = saving || !dirty();
  };
  const problems = () => {
    const { ignored, missing, schemaError } = api.config.problems();
    const list = (id, items) => $(id).replaceChildren(...items.map((text) => Object.assign(document.createElement('li'), { textContent: text })));
    list('missing', schemaError ? [`The extension's settings are broken: ${schemaError}`] : missing.map((m) => `Needs setting: ${m}`));
    list('ignored', ignored.map((m) => `Using the default, as the stored value doesn't fit: ${m}`));
    $('problems').hidden = !schemaError && !missing.length && !ignored.length;
  };
  const stage = (values) => {
    staged = values;
    pinned = pinnedPaths(staged, defaults);
    buttons();
  };

  form.addEventListener('json-form-change', (event) => {
    const value = event.detail.value;
    stage(value && typeof value === 'object' && !Array.isArray(value) ? value : {});
    form.errors = formErrors();
    status('');
  });
  editor.addEventListener('json-editor-change', (event) => {
    const value = event.detail.value;
    const values = showDefaults ? (stripDefaults(value, defaults, pinned) ?? {}) : value;
    stage(values && typeof values === 'object' && !Array.isArray(values) ? values : {});
    status('');
  });
  // "Overwrite" on a faded default row: that value, set.
  editor.addEventListener('json-editor-overwrite', (event) => {
    const { path, value } = event.detail ?? {};
    if (!path?.length) return;
    const next = cloneDeep(staged);
    setAt(next, path, value);
    stage(next);
    render();
  });

  const save = async () => {
    if (saving || !dirty()) return;
    const kept = Object.fromEntries(Object.entries(api.config.values()).filter(([key]) => secret.has(key)));
    const values = { ...sortJsonKeys(shown(staged)), ...kept };
    saving = true;
    buttons();
    status('Saving…');
    try {
      await api.config.set(values);
      saved = shown(values);
      stage(cloneDeep(saved));
      status('Saved.');
    } catch (error) {
      status(error.message, true);
    } finally {
      saving = false;
      buttons();
    }
  };
  $('save').addEventListener('click', save);
  $('revert').addEventListener('click', () => {
    stage(cloneDeep(saved));
    render();
    status('');
  });
  $('show-defaults').addEventListener('change', (event) => {
    showDefaults = event.target.checked;
    render();
  });
  $('json-view').addEventListener('change', (event) => {
    jsonView = event.target.checked;
    render();
  });
  document.addEventListener('keydown', (event) => {
    // An open drawer holds the page, Save included.
    if (!jsonView && form.drawersOpen) return;
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') {
      event.preventDefault();
      save();
    }
  });

  // A change made elsewhere: shown, unless there are edits staged here.
  api.config.onChange(() => {
    problems();
    const values = shown(api.config.values());
    if (saving || JSON.stringify(sortJsonKeys(values)) === JSON.stringify(sortJsonKeys(saved))) return;
    if (dirty()) {
      saved = values;
      buttons();
      status('Changed elsewhere: Save replaces that change, Revert shows it.');
      return;
    }
    saved = values;
    stage(cloneDeep(saved));
    render();
  });

  // Secrets: a masked field each. What's set isn't shown, only that it is.
  const secretRows = [...secret].map((key) => {
    const property = schema.properties[key];
    const row = document.createElement('li');
    const label = Object.assign(document.createElement('label'), { textContent: property.title ?? key, htmlFor: `secret-${key}` });
    const input = Object.assign(document.createElement('input'), { id: `secret-${key}`, type: 'password', autocomplete: 'off' });
    const saveButton = Object.assign(document.createElement('button'), { type: 'button', textContent: 'Save' });
    const clear = Object.assign(document.createElement('button'), { type: 'button', textContent: 'Clear' });
    const update = () => {
      const isSet = typeof api.config.values()[key] === 'string' && api.config.values()[key] !== '';
      input.placeholder = isSet ? 'Set (type to replace)' : schema.required?.includes(key) ? 'Not set (required)' : 'Not set';
      clear.disabled = !isSet;
    };
    const store = async (value) => {
      try {
        await api.config.set({ ...api.config.values(), [key]: value });
        input.value = '';
        status(value ? `${property.title ?? key} saved.` : `${property.title ?? key} cleared.`);
      } catch (error) {
        status(error.message, true);
      }
    };
    saveButton.addEventListener('click', () => input.value && store(input.value));
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && input.value) store(input.value);
    });
    clear.addEventListener('click', () => store(''));
    row.append(label, input, saveButton, clear);
    update();
    return { row, update };
  });
  $('secret-list').replaceChildren(...secretRows.map((r) => r.row));
  $('secrets').hidden = secretRows.length === 0;
  api.config.onChange(() => secretRows.forEach((r) => r.update()));

  problems();
  render();
}
