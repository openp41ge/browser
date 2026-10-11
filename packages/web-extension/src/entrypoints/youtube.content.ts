import { runFeature } from '@/core/run-feature';
import { youtubePip } from '@/features/youtube-pip';
import '@/features/youtube-pip/style.css';

export default defineContentScript({
  matches: ['*://*.youtube.com/*'],
  main(ctx) {
    runFeature(youtubePip, ctx);
  },
});
