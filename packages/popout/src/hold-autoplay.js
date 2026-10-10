// Copyright (c) 2026 Richard Kielty. MIT License.
//
// Runs before page scripts in pages opened while something is popped out:
// media that tries to start before the user has interacted with the page is
// paused, so it doesn't play over the pop-out.

window.addEventListener(
  'play',
  (event) => {
    if (!navigator.userActivation.hasBeenActive) event.target.pause();
  },
  true,
);
