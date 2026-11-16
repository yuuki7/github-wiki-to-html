import { defineConfig } from 'astro/config';
import expressiveCode from 'astro-expressive-code';
import { satteri } from '@astrojs/markdown-satteri';
import tableWrap from '../templates/table-wrap';

export default defineConfig({
  srcDir: './templates',
  markdown: {
    processor: satteri({ hastPlugins: [tableWrap] }),
  },
  // Static files served as they are, inside the templates
  // tree like the rest of the site sources.
  publicDir: './templates/public',
  compressHTML: false,
  integrations: [
    // Code blocks: frames and copy buttons from Expressive
    // Code. Its options are in ec.config.mjs, the file
    // Expressive Code reads itself.
    expressiveCode(),
  ],
  build: {
    assets: 'assets',
    format: 'file',
    inlineStylesheets: 'never',
  },
  vite: {
    preview: {
      // The preview is also opened through the machine's
      // Tailscale name, for checking the site on a phone.
      // Vite refuses hosts it does not know, so allow that
      // one name.
      allowedHosts: ['yuukis-macbook-neo.tail8d2685.ts.net'],
    },
    build: {
      minify: false,
      cssMinify: false,
      rollupOptions: {
        output: {
          assetFileNames: 'assets/[name][extname]',
        },
      },
    },
  },
});
