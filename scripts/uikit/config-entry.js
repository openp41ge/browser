// Copyright (c) 2026 Richard Kielty. MIT License.
//
// The extension config logic alone, for the extension runtime in pages
// (app/extensions/runtime.js), which can't carry all of uikit.js into each
// page. Bundled by scripts/update-uikit into
// third_party/openp41ge-uikit/config.js.

export { validateConfigSchema, configDefaults, configErrors, mergeConfig } from "openp41ge-sdk/config";
