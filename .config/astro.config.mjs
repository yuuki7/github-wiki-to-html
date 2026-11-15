import { defineConfig } from 'astro/config';

export default defineConfig({
  srcDir: './templates',
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
