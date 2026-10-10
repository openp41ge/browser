// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_POPOUT_POPOUT_SCRIPTS_H_
#define OPENP41GE_EXPLORER_POPOUT_POPOUT_SCRIPTS_H_

#include <string>

// The pop-out's page-side scripts, from the app bundle
// (Contents/Resources/popout; sources in packages/popout/src).
namespace popout_scripts {

// core.js. Evaluating it defines `__openp41ge.popout()` and friends in the
// page. Site presets come from extensions, not the browser.
const std::string& Library();

// Pauses media that starts before the user has interacted with the page.
const std::string& HoldAutoplay();

}  // namespace popout_scripts

#endif  // OPENP41GE_EXPLORER_POPOUT_POPOUT_SCRIPTS_H_
