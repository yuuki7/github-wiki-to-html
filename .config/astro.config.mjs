import { defineConfig } from 'astro/config';

export default defineConfig({
  build: {
    format: 'file',
    inlineStylesheets: 'never',
    assets: 'assets',
  },
  vite: {
    build: {
      minify: false,
      cssMinify: false,
      rollupOptions: {
        output: {
          assetFileNames: 'assets/[name][extname]'
        }
      }
    }
  },
  srcDir: './templates',
  compressHTML: false,
});
