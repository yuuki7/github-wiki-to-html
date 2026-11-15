import { defineConfig } from 'astro/config';

export default defineConfig({
  srcDir: './templates',
  // Static files served as they are, inside the templates
  // tree like the rest of the site sources.
  publicDir: './templates/public',
  compressHTML: false,
  markdown: {
    shikiConfig: {
      // A light theme, rather than Shiki's default github-dark:
      // the pages themselves have a light background.
      theme: 'github-light',
    },
  },
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
