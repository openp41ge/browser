// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Reading an extension's settings, for the extension runtime in content
// scripts (runtime.js) and in the extension's own pages (page-runtime.js).
// See plans/2026-10-14-extension-system.md, "Settings".
//
// This file is one function expression. The browser calls it with the code
// editor's config logic (openp41ge-sdk's config.ts: validateConfigSchema,
// configDefaults, configErrors, mergeConfig) and passes on what it returns:
// that logic, plus
//
//   read(schema, values) -> { config, ignored, missing, schemaError }
//     config       the user's values merged over the schema's defaults,
//                  leaving out each stored value that doesn't fit the schema
//                  (say, after an update changed it), so its default applies
//     ignored      a message for each value left out
//     missing      a message for each required setting with no value (no
//                  default, and the user hasn't set it): the extension needs
//                  setup
//     schemaError  why the schema is broken, or null (then config is {})
//   fits(schema, values) -> messages: why `values`, as the user's values,
//                  don't fit (each checked on its own; required settings
//                  may be left unset)
//   withoutSecrets(schema, value) -> `value` without the settings the
//                  schema marks "secret": true

(lib) => {
  'use strict';

  // The schema for checking each stored value on its own.
  const each = (schema) => ({
    type: 'object',
    properties: schema.properties,
    additionalProperties: schema.additionalProperties,
  });

  const fits = (schema, values) => {
    if (values === null || typeof values !== 'object' || Array.isArray(values)) return ['must be an object'];
    return Object.entries(values).flatMap(([key, value]) => lib.configErrors(each(schema), { [key]: value }));
  };

  const read = (schema, values) => {
    try {
      lib.validateConfigSchema(schema);
    } catch (error) {
      return { config: {}, ignored: [], missing: [], schemaError: error.message };
    }
    const kept = {};
    const ignored = [];
    for (const [key, value] of Object.entries(values)) {
      const errors = lib.configErrors(each(schema), { [key]: value });
      if (errors.length) ignored.push(...errors);
      else kept[key] = value;
    }
    const config = lib.mergeConfig(lib.configDefaults(schema), kept);
    return { config, ignored, missing: lib.configErrors(schema, config), schemaError: null };
  };

  const withoutSecrets = (schema, value) => {
    if (!schema?.properties || value === null || typeof value !== 'object' || Array.isArray(value)) return value;
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      const sub = schema.properties[key];
      if (sub?.secret === true) continue;
      out[key] = withoutSecrets(sub, item);
    }
    return out;
  };

  return Object.freeze({ ...lib, read, fits, withoutSecrets });
}
