// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Bundles entry.js with everything it imports (Lit and the openp41ge-*
// packages, from source) into one ES module, uikit.js; or, with
// BUNDLE=config, config-entry.js into config.js, a plain script that
// defines `openp41geConfig`. Run by scripts/update-uikit, with Vite from the
// code repo; CODE_DIR is that repo's worktree.

import path from "node:path";

const code = process.env.CODE_DIR;
const packages = path.join(code, "packages");
const config = process.env.BUNDLE === "config";

export default {
  root: import.meta.dirname,
  logLevel: "warn",
  resolve: {
    alias: [
      // openp41ge-<name>[/<path>] -> packages/openp41ge-<name>/src[/<path>]
      { find: /^openp41ge-([a-z-]+)(\/.*)?$/, replacement: `${packages}/openp41ge-$1/src$2` },
      // Lit as the code repo has it.
      { find: /^lit(\/.*)?$/, replacement: `${path.join(code, "node_modules/lit")}$1` },
    ],
  },
  build: {
    lib: config
      ? {
          entry: path.join(import.meta.dirname, "config-entry.js"),
          formats: ["iife"],
          name: "openp41geConfig",
          fileName: () => "config.js",
        }
      : { entry: path.join(import.meta.dirname, "entry.js"), formats: ["es"], fileName: () => "uikit.js" },
    outDir: process.env.OUT_DIR,
    emptyOutDir: true,
    minify: false,
  },
};
