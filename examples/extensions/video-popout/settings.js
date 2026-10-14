// The extension's settings page: one menu for the "corner" setting, from
// the schema in the manifest. Saving changes it in every tab at once (the
// content script hears it with openp41ge.config.onChange); videos already
// showing the button move it the next time the pointer moves.

const { corner: schema } = openp41ge.config.schema().properties;
const menu = document.getElementById('corner');
const status = document.getElementById('status');

document.getElementById('corner-title').textContent = schema.title;
for (const value of schema.enum) menu.append(new Option(value.replace('-', ' '), value));

const show = () => {
  menu.value = openp41ge.config.get().corner;
  if (!('corner' in openp41ge.config.values())) status.textContent = 'Using the default.';
};
show();
openp41ge.config.onChange(show);

menu.addEventListener('change', async () => {
  try {
    await openp41ge.config.set({ ...openp41ge.config.values(), corner: menu.value });
    status.textContent = 'Saved.';
  } catch (error) {
    status.textContent = error.message;
  }
});

document.getElementById('reset').addEventListener('click', () => openp41ge.config.reset('corner'));
