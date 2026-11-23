import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import { z } from "zod";
import { missingVersions, pageHref, supportedLanguages } from "./i18n";
import { renderMarkdown, type Heading } from "./markdown";
import type { AlternateLink, ArticleEntry, PageEntry } from "./types";

// The content layer: the site's pages are the files under md/,
// one per page per language, each a GFM document with YAML
// front matter. This module reads them once, validates every
// file's front matter, and hands the entries to the pages.
// Rendering an entry stays here too, so the whole collection
// is a pure function of the files.

const mdDir = path.join(process.cwd(), "md");

// A date as the front matter carries it: an ISO 8601 string
// or a YAML date, normalized here to a string. A string that
// is not a date fails the build here, naming the file,
// instead of crashing a presenter later.
const dateLike = z
  .union([z.iso.datetime({ offset: true }), z.date()])
  .transform((v) => (v instanceof Date ? v.toISOString() : v));

const pageSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("article"),
    title: z.string(),
    slug: z.string(),
    author: z.string(),
    creation_date: dateLike,
    modified_date: dateLike,
    language: z.string(),
    original_language: z.string().optional(),
    translation: z.boolean().default(false).optional(),
    listed: z.boolean().default(true).optional(),
  }),
  z.object({
    kind: z.literal("redirect"),
    title: z.string(),
    slug: z.string(),
    target_slug: z.string(),
  }),
  z.object({
    kind: z.literal("special"),
    title: z.string(),
    slug: z.string(),
    // The converter omits the key when the site has no language;
    // missingVersions in i18n.ts treats such a page the same way.
    language: z.string().optional(),
  }),
]);

let entriesCache: PageEntry[] | null = null;

// Every content file under md/, validated, in path order.
export function getEntries(): PageEntry[] {
  if (entriesCache) return entriesCache;
  const files: string[] = [];
  const walk = (dir: string): void => {
    for (const name of fs.readdirSync(dir).sort()) {
      const full = path.join(dir, name);
      if (fs.statSync(full).isDirectory()) walk(full);
      else if (name.endsWith(".md")) files.push(full);
    }
  };
  walk(mdDir);

  entriesCache = files.map((full) => {
    const filePath = path.relative(mdDir, full);
    const { data, content } = matter(fs.readFileSync(full, "utf8"));
    const parsed = pageSchema.safeParse(data);
    if (!parsed.success) {
      throw new Error(
        `${filePath}: invalid front matter: ${parsed.error.issues
          .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
          .join("; ")}`,
      );
    }
    return {
      id: filePath.replace(/\.md$/, ""),
      filePath,
      data: parsed.data,
      body: content,
    };
  });
  return entriesCache;
}

// Refuse to build while any page lacks a version in some
// language; missingVersions in i18n.ts states the rule.
export function assertComplete(entries: PageEntry[]): void {
  const missing = missingVersions(entries);
  if (missing.length > 0) {
    throw new Error(`missing translations: ${missing.join(", ")}`);
  }
}

const renderedCache = new Map<
  string,
  Promise<{ html: string; headings: Heading[] }>
>();

// One entry rendered: its body as HTML and its headings. The
// images a body references live in the entry's own directory.
export function renderEntry(
  entry: PageEntry,
): Promise<{ html: string; headings: Heading[] }> {
  let rendered = renderedCache.get(entry.id);
  if (!rendered) {
    rendered = renderMarkdown(
      entry.body,
      path.join(mdDir, path.dirname(entry.filePath)),
    );
    renderedCache.set(entry.id, rendered);
  }
  return rendered;
}

// A special page (Home, _Footer, and the like) in the given
// language, falling back to the fallback language's version
// when the page has not been translated into the given one.
export function specialPage(
  entries: PageEntry[],
  slug: string,
  language: string,
  fallbackLanguage: string,
): PageEntry | undefined {
  return (
    entries.find(
      (entry) =>
        entry.data.kind === "special" &&
        entry.data.slug === slug &&
        entry.data.language === language,
    ) ??
    entries.find(
      (entry) =>
        entry.data.kind === "special" &&
        entry.data.slug === slug &&
        entry.data.language === fallbackLanguage,
    )
  );
}

// The data one article page is assembled from, derived from its
// entry and the whole collection. Rendering the entry and its
// footer stays with the view; everything that is a pure function
// of the collection lives here, where it can be read and tested
// apart from the markup.
export function articlePageData(
  entry: PageEntry,
  entries: PageEntry[],
  lang: string,
): {
  isRedirect: boolean;
  originalLanguage: string | undefined;
  articleLinks: AlternateLink[];
  targetHref: string | undefined;
  isTranslation: boolean;
} {
  const isRedirect = entry.data.kind === "redirect";

  // The article's original language: the page's own language for
  // an original, the recorded original language for a
  // translation. Which languages have a version of the article
  // is never checked here. Every supported language is expected
  // to have one, and seeing to that is the translation side's
  // responsibility.
  const originalLanguage =
    entry.data.kind === "article"
      ? (entry.data.original_language ?? entry.data.language)
      : undefined;

  // This article in every supported language, for the language
  // switcher and the hreflang links alike: the original at the
  // root, a translation under its language.
  const articleLinks = isRedirect
    ? []
    : supportedLanguages.map((language) => ({
        language,
        href: pageHref(
          language,
          entry.data.slug,
          language !== originalLanguage,
        ),
      }));

  // For a redirect, the target in the language the redirect
  // serves: the original at the root when that is the target's
  // original language, the translation under its language
  // otherwise.
  const targetSlug =
    entry.data.kind === "redirect" ? entry.data.target_slug : undefined;
  const targetOriginal =
    targetSlug === undefined
      ? undefined
      : entries.find(
          (e): e is ArticleEntry =>
            e.data.kind === "article" &&
            e.data.slug === targetSlug &&
            !e.data.translation,
        );
  const targetHref =
    targetSlug === undefined
      ? undefined
      : pageHref(lang, targetSlug, lang !== targetOriginal?.data.language);

  const isTranslation =
    entry.data.kind === "article" && (entry.data.translation ?? false);

  return {
    isRedirect,
    originalLanguage,
    articleLinks,
    targetHref,
    isTranslation,
  };
}
