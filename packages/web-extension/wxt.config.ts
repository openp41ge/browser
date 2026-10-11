import { defineConfig } from 'wxt';

// https://wxt.dev/api/config.html
export default defineConfig({
  srcDir: 'src',
  manifest: {
    name: 'Internet Utility Belt',
    description: 'Small quality-of-life tools for the web.',
    permissions: ['storage'],
  },
});
