import { defineEcConfig, definePlugin } from 'astro-expressive-code';
import { bundledLanguagesInfo } from 'shiki';

// Expressive Code's options. They live in this file, rather
// than in the Astro config, because Expressive Code reads
// this file itself when it renders code blocks. Code like
// the plugin below cannot travel through the Astro config.

// The display name of each language Shiki knows, by its
// ID and by each of its aliases: py is an alias of Python,
// for example. A language Shiki does not know is missing
// here, and the plugin below falls back to the ID itself.
const languageNames = new Map();
for (const info of bundledLanguagesInfo) {
  languageNames.set(info.id, info.name);
  for (const alias of info.aliases ?? []) {
    languageNames.set(alias, info.name);
  }
}

// An Expressive Code plugin that titles every code block
// with its language. Expressive Code shows a frame title
// only when the block itself sets one, so a block without
// a title would show nothing. Setting the title here, from
// the language's display name, keeps the language visible
// on every block through the title display Expressive Code
// already has.
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
      codeBlock.props.title =
        languageNames.get(codeBlock.language) ?? codeBlock.language;
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
  // LilyPond has no Shiki grammar. Aliasing it to plain text
  // highlights its blocks with no warning, while the blocks
  // keep naming LilyPond as their language.
  shiki: {
    langAlias: {
      lilypond: 'txt',
    },
  },
  plugins: [languageTitle],
});
