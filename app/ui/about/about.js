// Copyright (c) 2026 Richard Kielty. MIT License.
//
// About openp41ge explorer: fills in the version and engine, which the
// browser serves at openp41ge://about/info.js (src/ui/ui_resources.mm).

import info from './info.js';

const development = info.channel === 'dev' ? ' (development build)' : '';
// A release's build number is its own; a development build's is its version.
const build = info.build && info.build !== info.version ? ` (build ${info.build})` : '';
document.getElementById('version').textContent = `${info.version}${build}${development}`;
document.getElementById('engine').textContent = `Chromium ${info.chromium}, CEF ${info.cef}`;
