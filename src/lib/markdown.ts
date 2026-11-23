import fs from "node:fs";
import path from "node:path";
import type { Element, ElementContent, Root, Text } from "hast";
import { imageSize } from "image-size";
import { bundledLanguagesInfo, codeToHast } from "shiki";
import { unified } from "unified";
import remarkGfm from "remark-gfm";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import rehypeRaw from "rehype-raw";
import rehypeSlug from "rehype-slug";
import rehypeStringify from "rehype-stringify";
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

// Languages whose blocks are highlighted as another language.
// LilyPond has no Shiki grammar; aliasing it to plain text
// highlights its blocks with no warning, while the blocks keep
// naming LilyPond as their language.
const languageAliases: Record<string, string> = {
  lilypond: "txt",
};

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
    const highlightLanguage = languageAliases[language] ?? language;

    let lines: ElementContent[] = [];
    try {
      const highlighted = await codeToHast(text, {
        lang: highlightLanguage,
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
      lines = highlightedCode?.children ?? [];
    } catch {
      lines = [{ type: "text", value: text } as Text];
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
    try {
      const size = imageSize(
        fs.readFileSync(path.join(assetDir, decodeURIComponent(name))),
      );
      if (size.width !== undefined) node.properties.width = size.width;
      if (size.height !== undefined) node.properties.height = size.height;
    } catch {
      // No readable file: the reference is rewritten anyway,
      // and the element simply carries no size.
    }
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

// Renders one article's Markdown body to HTML, and collects
// its headings on the way. The pipeline is the unified one:
// GFM parsing, heading ids, then the site's own steps — image
// references, table wrapping, and code block highlighting.
// Math is left as the $...$ text the authors wrote; MathJax
// renders it in the reader's browser, as the site has always
// done.
export async function renderMarkdown(
  body: string,
  assetDir: string,
): Promise<{ html: string; headings: Heading[] }> {
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

  const html = unified()
    .use(rehypeStringify, { allowDangerousHtml: true })
    .stringify(tree);
  return { html, headings };
}
