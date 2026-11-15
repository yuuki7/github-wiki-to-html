import { defineEcConfig, definePlugin } from 'astro-expressive-code';

// Expressive Code's options. They live in this file, rather
// than in the Astro config, because Expressive Code reads
// this file itself when it renders code blocks. Code like
// the plugin below cannot travel through the Astro config.

// An Expressive Code plugin that titles every code block
// with its language. Expressive Code shows a frame title
// only when the block itself sets one, so a block without
// a title would show nothing. Setting the title here, from
// the language, keeps the language visible on every block
// through the title display Expressive Code already has.
const languageTitle = definePlugin({
  name: 'Language title',
  hooks: {
    // Runs after the frames plugin has had its chance to
    // find a title in the block's meta string or a file name
    // comment, and fills in the language only when neither
    // gave one.
    preprocessCode: ({ codeBlock }) => {
      // Plain text blocks have no language worth showing.
      if (codeBlock.props.title || !codeBlock.language) return;
      if (codeBlock.language === 'plaintext') return;
      codeBlock.props.title = codeBlock.language;
    },
  },
});

export default defineEcConfig({
  // A light theme, rather than a dark one: the pages
  // themselves have a light background.
  themes: ['github-light'],
  // The code background is GitHub's code block grey instead
  // of the theme's white, so a block reads as a block on
  // the page.
  styleOverrides: {
    codeBackground: '#f6f8fa',
    frames: {
      editorBackground: '#f6f8fa',
    },
  },
  plugins: [languageTitle],
});
