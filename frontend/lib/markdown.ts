import fs from "node:fs";
import path from "node:path";
import type { Element, ElementContent, Root, Text } from "hast";
import { toJsxRuntime } from "hast-util-to-jsx-runtime";
import { imageSize } from "image-size";
import type { ReactNode } from "react";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import { bundledLanguagesInfo, codeToHast, ShikiError } from "shiki";
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
// A language Shiki does not know is missing here, and the code
// block plugin below falls back to the ID itself.
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

// The raw code of a <code> element: the text of its children.
const codeText = (code: Element): string =>
  code.children
    .map((child) => (child.type === "text" ? child.value : ""))
    .join("");

// The language a code block names, from its class, or
// "plaintext" when it names none.
const blockLanguage = (code: Element): string => {
  const classes = code.properties?.className;
  if (Array.isArray(classes)) {
    for (const name of classes) {
      if (typeof name === "string" && name.startsWith("language-")) {
        return name.slice("language-".length);
      }
    }
  }
  return "plaintext";
};

// XXX: whether an error from Shiki is its "no such language"
// error, judged by the error's full message. Shiki offers no
// fallback option for a language it does not know, and no way
// to ask in advance — its grammars load lazily, so the loaded
// set cannot answer for a name not yet used. The message is
// not a stable API, and it is not even one message: another
// entry point into the same library words it differently. If
// a Shiki upgrade rewords this one, the test stops matching
// and the error propagates, failing the build loudly rather
// than misrendering silently. There is no better test the
// library gives.
const isUnknownLanguageError = (error: unknown, language: string): boolean =>
  error instanceof ShikiError &&
  error.message ===
    `Language \`${language}\` is not included in this bundle. You may want to load it from external source.`;

// Code blocks: Shiki highlights the code at build time, and the
// block is framed with its language as its title, in the shape
// the site's stylesheet styles: a figure with a header, the
// code, and a copy button whose behaviour the shell's client
// script provides. A block in a language Shiki does not know is
// highlighted as plain text and keeps its own language's name.
const codeBlocks = () => async (tree: Root) => {
  const blocks: { pre: Element; parent: Root | Element; index: number }[] = [];
  visit(tree, "element", (node, index, parent) => {
    if (node.tagName !== "pre" || !parent || index === undefined) return;
    const code = node.children.find(
      (child): child is Element =>
        child.type === "element" && child.tagName === "code",
    );
    if (code)
      blocks.push({ pre: node, parent: parent as Root | Element, index });
  });

  for (const { pre, parent, index } of blocks) {
    const code = pre.children.find(
      (child): child is Element =>
        child.type === "element" && child.tagName === "code",
    )!;
    const text = codeText(code).replace(/\n$/, "");
    const language = blockLanguage(code);

    // The lines of the block highlighted in the given language.
    // A result with no code node is a broken highlight, not a
    // rendering of the block, whichever language produced it.
    const highlightLines = async (lang: string): Promise<ElementContent[]> => {
      const highlighted = await codeToHast(text, {
        lang,
        theme: "github-light",
      });
      const highlightedPre = highlighted.children.find(
        (child): child is Element =>
          child.type === "element" && child.tagName === "pre",
      );
      const highlightedCode = highlightedPre?.children.find(
        (child): child is Element =>
          child.type === "element" && child.tagName === "code",
      );
      if (!highlightedCode) {
        throw new Error(`Shiki returned no code node for language ${language}`);
      }
      return highlightedCode.children;
    };

    let lines: ElementContent[];
    try {
      lines = await highlightLines(language);
    } catch (error) {
      if (!isUnknownLanguageError(error, language)) throw error;
      lines = await highlightLines("txt");
    }

    // Plain text blocks have no language worth showing; every
    // other block is titled with its language's display name.
    const title =
      language === "plaintext"
        ? undefined
        : (languageNames.get(language) ?? language);

    const figure: Element = {
      type: "element",
      tagName: "figure",
      properties: { className: title ? ["frame", "has-title"] : ["frame"] },
      children: [
        {
          type: "element",
          tagName: "figcaption",
          properties: { className: ["header"] },
          children: title
            ? [
                {
                  type: "element",
                  tagName: "span",
                  properties: { className: ["title"] },
                  children: [{ type: "text", value: title }],
                },
              ]
            : [],
        },
        {
          type: "element",
          tagName: "pre",
          properties: { dataLanguage: language },
          children: [
            {
              type: "element",
              tagName: "code",
              properties: {},
              children: lines,
            },
          ],
        },
        {
          type: "element",
          tagName: "div",
          properties: { className: ["copy"] },
          children: [
            {
              type: "element",
              tagName: "div",
              properties: { "aria-live": "polite" },
              children: [],
            },
            {
              type: "element",
              tagName: "button",
              properties: {
                title: "Copy to clipboard",
                dataCopied: "Copied!",
                dataCode: text,
              },
              children: [
                {
                  type: "element",
                  tagName: "div",
                  properties: {},
                  children: [],
                },
              ],
            },
          ],
        },
      ],
    };
    parent.children[index] = {
      type: "element",
      tagName: "div",
      properties: { className: ["expressive-code"] },
      children: [figure],
    };
  }
};

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
// steps — image references, table wrapping, and code block
// highlighting — and the finished tree becomes JSX. Math is
// left as the $...$ text the authors wrote; MathJax renders
// it in the reader's browser, as the site has always done.
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
    .use(rehypeRaw)
    .use(rehypeSlug)
    .use(images, assetDir)
    .use(codeBlocks);
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
