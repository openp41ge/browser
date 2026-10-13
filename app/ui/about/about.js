// Copyright (c) 2026 Richard Kielty. MIT License.
//
// About openp41ge explorer: fills in the version, which the browser serves
// at openp41ge://about/info.js (src/ui/ui_resources.mm).

import info from './info.js';

// A release's build number is its own; a development build's is its version.
const build = info.build && info.build !== info.version ? ` (build ${info.build})` : '';
const development = info.channel === 'dev' ? ' (development build)' : '';
document.getElementById('version').textContent = `Version ${info.version}${build}${development}`;
