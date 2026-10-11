/**
 * Element pop-out (@openp41ge/popout): moves an element into a Document
 * Picture-in-Picture window as real DOM, with frameless-window controls and
 * site presets. In openp41ge explorer the window is frameless and opens
 * right over the element; in other Chromium browsers it's their usual PiP
 * window.
 */
import '@openp41ge/popout/core';

export const popout = globalThis.__openp41ge;

export function isDocumentPipSupported(): boolean {
  return 'documentPictureInPicture' in window;
}
