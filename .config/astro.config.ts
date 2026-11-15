import { defineConfig } from 'astro/config';
import expressiveCode from 'astro-expressive-code';

export default defineConfig({
  srcDir: './templates',
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
