// A "Pop out" button in a corner of the video under the pointer (the
// "corner" setting), which pops the video out with openp41ge.popout. One
// button, placed over whichever video the pointer is on (sites cover their
// videos with their own controls, so the pointer's position is checked, not
// what it's over).

let { corner } = openp41ge.config.get();
openp41ge.config.onChange((config) => ({ corner } = config));

const button = document.createElement('button');
button.className = 'openp41ge-video-popout';
button.textContent = 'Pop out';
button.hidden = true;
document.documentElement.append(button);

let video = null;

const videoAt = (x, y) =>
  [...document.querySelectorAll('video')].find((v) => {
    const r = v.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
  }) ?? null;

const place = () => {
  if (!video || !video.isConnected) {
    button.hidden = true;
    return;
  }
  const r = video.getBoundingClientRect();
  button.hidden = false;
  const top = Math.max(r.top, 0) + 10;
  const bottom = Math.min(r.bottom, innerHeight) - button.offsetHeight - 10;
  button.style.top = `${corner.startsWith('bottom') ? bottom : top}px`;
  button.style.left = `${corner.endsWith('left') ? r.left + 10 : r.right - button.offsetWidth - 10}px`;
};

document.addEventListener(
  'pointermove',
  (event) => {
    if (event.target === button) return;
    video = videoAt(event.clientX, event.clientY);
    place();
  },
  { passive: true },
);
document.addEventListener('scroll', place, { passive: true, capture: true });

button.addEventListener('click', async (event) => {
  event.stopPropagation();
  if (!video) return;
  const popped = video;
  video = null;
  place();
  const result = await openp41ge.popout.popout({ element: popped });
  if (result !== 'opened') console.warn(`[Video pop-out] ${result}`);
});
