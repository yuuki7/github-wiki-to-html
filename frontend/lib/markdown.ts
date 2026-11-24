import fs from "node:fs";
import path from "node:path";
import type { Element, Root, Text } from "hast";
import { toJsxRuntime } from "hast-util-to-jsx-runtime";
import { imageSize } from "image-size";
import type { ReactNode } from "react";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import rehypeExpressiveCode, {
  createRenderer,
  definePlugin,
} from "rehype-expressive-code";
import { bundledLanguagesInfo } from "shiki";
import { unified } from "unified";
import remarkGfm from "remark-gfm";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import rehypeRaw from "rehype-raw";
import rehypeSlug from "rehype-slug";
import { visit } from "unist-util-visit";

// One heading of a rendered article, for the table of contents:
// its depth, the id the renderer gave it, and its text.
export interface Heading {
  depth: number;
  slug: string;
  text: string;
}

// The display name of each language Shiki knows, by its ID and
// by each of its aliases: py is an alias of Python, for example.
// A language Shiki does not know is missing here, and the
// language title plugin below falls back to the ID itself.
const languageNames = new Map<string, string>();
for (const info of bundledLanguagesInfo) {
  languageNames.set(info.id, info.name);
  for (const alias of info.aliases ?? []) {
    languageNames.set(alias, info.name);
  }
}

// Smart punctuation: prose is set with typographic marks —
// quotes curl, an apostrophe is a right single quote, three
// dots are an ellipsis, and hyphen runs are en and em dashes.
// The transform works on the parsed text, so it reaches
// everything a reader reads as text (a $...$ formula is text
// until the browser's MathJax renders it) and nothing else:
// code, whose characters are exact, and raw HTML are not
// text nodes and keep the characters they were written with.

const smartify = (value: string): string => {
  let out = "";
  let i = 0;
  while (i < value.length) {
    if (value.startsWith("---", i)) {
      out += "—";
      i += 3;
    } else if (value.startsWith("--", i)) {
      out += "–";
      i += 2;
    } else if (value.startsWith("...", i)) {
      out += "…";
      i += 3;
    } else if (value[i] === '"') {
      const prev = out[out.length - 1];
      const next = value[i + 1];
      // A quote opens when text follows it and it does not
      // sit inside a word: what precedes it may be anything
      // but a letter or digit of the same word — a space, a
      // punctuation mark, or another script's character, as
      // when a quoted English phrase follows Japanese text.
      const opens =
        next !== undefined &&
        !/\s/.test(next) &&
        !(prev !== undefined && /[A-Za-z0-9]/.test(prev));
      out += opens ? "“" : "”";
      i += 1;
    } else if (value[i] === "'") {
      const prev = out[out.length - 1];
      const next = value[i + 1];
      // A single quote opens only when its pair closes later
      // in the same text; every other one is an apostrophe.
      const opens =
        next !== undefined &&
        /[A-Za-z0-9]/.test(next) &&
        !(prev !== undefined && /[A-Za-z0-9]/.test(prev)) &&
        value.indexOf("'", i + 1) !== -1;
      out += opens ? "‘" : "’";
      i += 1;
    } else {
      out += value[i];
      i += 1;
    }
  }
  return out;
};

const smartPunctuation = () => (tree: Root) => {
  visit(tree, "text", (node) => {
    (node as unknown as Text).value = smartify((node as unknown as Text).value);
  });
  // An image's alternative text is prose too: it is read
  // aloud and shown in the image's place, so it is set with
  // the same marks. In the tree it is a plain string on the
  // image node, not a text node.
  visit(tree, "image", (node) => {
    const image = node as unknown as { alt?: string | null };
    if (image.alt) image.alt = smartify(image.alt);
  });
};

// An Expressive Code plugin that titles every code block
// with its language. Expressive Code shows a frame title
// only when the block itself sets one, so a block without
// a title would show nothing. Setting the title here, from
// the language's display name, keeps the language visible
// on every block through the title display Expressive Code
// already has.
const languageTitle = definePlugin({
  name: "Language title",
  hooks: {
    // Runs after the frames plugin has had its chance to
    // find a title in the block's meta string or a file name
    // comment, and fills in the language only when neither
    // gave one.
    preprocessCode: ({ codeBlock }) => {
      // Plain text blocks have no language worth showing.
      if (codeBlock.props.title || !codeBlock.language) return;
      if (codeBlock.language === "plaintext") return;
      codeBlock.props.title =
        languageNames.get(codeBlock.language) ?? codeBlock.language;
    },
  },
});

// Images written with a relative path live beside the article's
// file and are served as site assets: the build copies them
// into the output's assets (see scripts/copy-assets.mjs), and
// the reference is rewritten to that location. The element
// carries the image's own size, so the page does not move when
// the image loads.
const images = (assetDir: string) => (tree: Root) => {
  visit(tree, "element", (node) => {
    if (node.tagName !== "img") return;
    const src = node.properties?.src;
    if (typeof src !== "string") return;
    if (src.startsWith("/") || /^[a-z][a-z0-9+.-]*:/i.test(src)) return;
    const name = path.basename(src);
    node.properties.src = `/assets/${name}`;
    node.properties.loading = "lazy";
    node.properties.decoding = "async";
    const assetPath = path.join(assetDir, decodeURIComponent(name));
    let size;
    try {
      size = imageSize(fs.readFileSync(assetPath));
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new Error(
        `cannot resolve local image ${src} from ${assetDir}: ${detail}`,
      );
    }
    if (size.width === undefined || size.height === undefined) {
      throw new Error(`image dimensions are unavailable for ${assetPath}`);
    }
    node.properties.width = size.width;
    node.properties.height = size.height;
  });
};

// Wraps every table the Markdown produces in a container
// that scrolls sideways. The step runs before raw HTML is
// parsed into elements, so a table the author wrote as HTML
// — their own markup, already exactly what they meant — is
// left as written.
//
// A table wider than the article column cannot be made to
// fit: with automatic table layout its width is set by its
// contents. The choices are to let it stretch the page, to
// force it narrower and break the cell text wherever the
// width runs out, or to restyle the table element itself
// so it can scroll, which costs the table its meaning for
// assistive technology. Wrapping is the remaining option:
// the table stays exactly as it is, and the container,
// whose only job is scrolling, takes the overflow. The
// container is focusable so the table can also be scrolled
// with a keyboard.
const tableWrap = () => (tree: Root) => {
  visit(tree, "element", (node, index, parent) => {
    if (node.tagName !== "table" || !parent || index === undefined) return;
    (parent as Root | Element).children[index] = {
      type: "element",
      tagName: "div",
      properties: { className: ["table-scroll"], tabIndex: 0 },
      children: [node],
    };
  });
};

// The text of a heading, for the table of contents.
const headingText = (node: Element): string =>
  node.children
    .map((child) => {
      if (child.type === "text") return child.value;
      if (child.type === "element") return headingText(child);
      return "";
    })
    .join("");

// Renders one article's Markdown body as React elements, and
// collects its headings on the way. The pipeline is the
// unified one: GFM parsing, heading ids, then the site's own
// steps — image references and table wrapping — and code
// blocks rendered by Expressive Code, and the finished tree
// becomes JSX. Math is left as the $...$ text the authors
// wrote; MathJax renders it in the reader's browser, as the
// site has always done.
export async function renderMarkdown(
  body: string,
  assetDir: string,
): Promise<{ body: ReactNode; headings: Heading[] }> {
  const processor = unified()
    .use(remarkParse)
    .use(remarkGfm)
    .use(smartPunctuation)
    .use(remarkRehype, { allowDangerousHtml: true })
    .use(tableWrap)
    .use(rehypeExpressiveCode, {
      themes: ["github-light"],
      // The code background is GitHub's code block grey instead
      // of the theme's white, so a block reads as a block on
      // the page.
      styleOverrides: {
        codeBackground: "#f6f8fa",
        frames: { editorBackground: "#f6f8fa" },
      },
      // Code is preserved as written: Expressive Code's own
      // default replaces tabs with spaces.
      tabWidth: 0,
      // A block in a language Shiki does not know falls back
      // to plain text by design — the wiki's authors write
      // whatever languages they write — so the warning that
      // comes with the fallback is not news and is not logged.
      logger: { warn: () => {} },
      plugins: [languageTitle],
      // Expressive Code's own scripts are not emitted. A page
      // reached by the shell's in-place navigation cannot run
      // the scripts its document carries, so behaviour that
      // must work on every page — the copy buttons, keyboard
      // access to wide blocks — is the shell's, and the scripts
      // would only duplicate it on pages loaded in full.
      customCreateRenderer: async (options) => {
        const renderer = await createRenderer(options);
        return { ...renderer, jsModules: [] };
      },
    })
    .use(rehypeRaw)
    .use(rehypeSlug)
    .use(images, assetDir);
  const tree = (await processor.run(processor.parse(body))) as Root;

  const headings: Heading[] = [];
  visit(tree, "element", (node) => {
    const match = /^h([2-6])$/.exec(node.tagName);
    if (!match) return;
    const id = node.properties?.id;
    if (typeof id !== "string") return;
    headings.push({
      depth: Number(match[1]),
      slug: id,
      text: headingText(node),
    });
  });

  const rendered = toJsxRuntime(tree, { Fragment, jsx, jsxs });
  return { body: rendered, headings };
}
