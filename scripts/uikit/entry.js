// Copyright (c) 2026 Richard Kielty. MIT License.
//
// What the browser takes from the openp41ge code editor's UI kit, bundled by
// scripts/update-uikit into third_party/openp41ge-uikit/.

export {
  JsonEditorElement,
  setJsonEditorDefaults,
  JSON_EDITOR_CHANGE,
  JSON_EDITOR_OVERWRITE,
  cloneDeep,
  mergeDefaults,
  pinnedPaths,
  setAt,
  sortJsonKeys,
  stripDefaults,
} from "openp41ge-sdk-uikit/json-editor";
export { validateConfigSchema, configDefaults, configErrors, mergeConfig } from "openp41ge-sdk/config";
