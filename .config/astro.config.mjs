import { defineConfig } from 'astro/config';

export default defineConfig({
  srcDir: './templates',
  compressHTML: false,
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
