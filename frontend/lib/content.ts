import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import { missingVersions, supportedLanguages } from "./i18n";
import { renderMarkdown, type Heading } from "./markdown";
import { parsePageData } from "./page-schema";
import type { PageEntry } from "./types";

// The content layer: the site's pages are the files under md/,
// one per page per language, each a GFM document with YAML
// front matter. This module reads them once, validates every
// file's front matter, and hands the entries to the pages.
// Rendering an entry stays here too, so the whole collection
// is a pure function of the files.

const mdDir = path.join(process.cwd(), "md");

// A date as the front matter carries it. Dates take one form
// in this project — ISO 8601, UTC, second precision — and the
// schema accepts nothing else: a string in any other form, and
// a YAML date with fractional seconds, fail the build here,
// naming the file, instead of being rewritten into form or
// crashing a presenter later. A YAML date arrives as a Date
// and is written in the same form, as a Temporal Instant at
// second precision. The fractional-second check comes first:
// the Instant's string form would silently truncate them.
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

  const entries = files.map((full) => {
    const filePath = path.relative(mdDir, full);
    const { data, content } = matter(fs.readFileSync(full, "utf8"));
    const parsed = parsePageData(data, filePath);
    return {
      id: filePath.replace(/\.md$/, ""),
      filePath,
      data: parsed,
      body: content,
    };
  });
  entriesCache = entries;
  return entries;
}

// Refuse to build while any page lacks a version in some
// language; missingVersions in i18n.ts states the rule.
export function assertComplete(entries: PageEntry[]): void {
  const supported = new Set(supportedLanguages);
  for (const entry of entries) {
    if (
      (entry.data.kind === "article" || entry.data.kind === "special") &&
      entry.data.language &&
      !supported.has(entry.data.language)
    ) {
      throw new Error(
        `${entry.filePath}: unsupported content language ${entry.data.language}`,
      );
    }
  }
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
