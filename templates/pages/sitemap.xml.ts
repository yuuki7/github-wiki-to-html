import { getCollection } from "astro:content";
import type { ArticleEntry } from "../types";
import {
  absoluteUrl,
  defaultLanguage,
  homeHref,
  pageHref,
  supportedLanguages,
} from "../i18n";

// The site's sitemap: one entry for the home page, then one
// entry per article, newest updated first. An entry's URL is
// the page's original version, and the entry names every
// language version of the page once, as its alternates, with
// the original as the default. The versions are not entries of
// their own: giving each version an entry with the same list
// of alternates would repeat the list once per version and
// grow this file by the square of the language count, while
// the pages' heads already declare the versions reciprocally.
// Redirect stubs are not pages and are not listed.

interface SitemapUrl {
  loc: string;
  lastmod?: string;
  alternates: { language: string; href: string }[];
  xDefault: string;
}

const escapeXml = (value: string): string =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

export async function GET() {
  const entries = await getCollection("pages");
  const urls: SitemapUrl[] = [];

  // The home page: the top page — the default language's home —
  // as the single entry, pinned first. The other languages'
  // homes are its alternates. Special pages carry no dates, so
  // the entry has no lastmod.
  urls.push({
    loc: absoluteUrl(homeHref(defaultLanguage)),
    alternates: supportedLanguages.map((language) => ({
      language,
      href: absoluteUrl(homeHref(language)),
    })),
    xDefault: absoluteUrl(homeHref(defaultLanguage)),
  });

  // Articles, grouped by slug: one entry per article, however
  // many languages it has versions in. A translation inherits
  // the original's dates, so a group has one date: the
  // article's last update, or its creation when it was never
  // updated.
  const articleEntries = entries.filter(
    (entry): entry is ArticleEntry => entry.data.kind === "article",
  );
  const versionsBySlug = new Map<string, ArticleEntry[]>();
  for (const entry of articleEntries) {
    const versions = versionsBySlug.get(entry.data.slug) ?? [];
    versions.push(entry);
    versionsBySlug.set(entry.data.slug, versions);
  }
  const groups = [...versionsBySlug.entries()].map(([slug, versions]) => {
    const hrefOf = (version: ArticleEntry): string =>
      absoluteUrl(
        pageHref(
          version.data.language,
          slug,
          version.data.translation ?? false,
        ),
      );
    const updated = (version: ArticleEntry): string =>
      version.data.modified_date;
    const original = versions.find((version) => !version.data.translation);
    const base = original ?? versions[0];
    // The versions in the site's language order, the same order
    // the pages' heads list them in.
    const ordered = [...versions].sort(
      (a, b) =>
        supportedLanguages.indexOf(a.data.language) -
        supportedLanguages.indexOf(b.data.language),
    );
    return {
      slug,
      date: updated(base),
      url: {
        loc: hrefOf(base),
        lastmod: updated(base),
        alternates: ordered.map((version) => ({
          language: version.data.language,
          href: hrefOf(version),
        })),
        xDefault: hrefOf(base),
      } satisfies SitemapUrl,
    };
  });
  // Newest updated first. The dates are ISO strings in one
  // format, so they order as plain strings; equal dates fall
  // back to the slug, to keep the output deterministic.
  groups.sort((a, b) =>
    a.date === b.date
      ? a.slug.localeCompare(b.slug)
      : b.date.localeCompare(a.date),
  );
  for (const group of groups) {
    urls.push(group.url);
  }

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ...urls.flatMap((url) => [
      "  <url>",
      `    <loc>${escapeXml(url.loc)}</loc>`,
      ...(url.lastmod
        ? [`    <lastmod>${escapeXml(url.lastmod)}</lastmod>`]
        : []),
      ...url.alternates.map(
        (alternate) =>
          `    <xhtml:link rel="alternate" hreflang="${escapeXml(alternate.language)}" href="${escapeXml(alternate.href)}"/>`,
      ),
      `    <xhtml:link rel="alternate" hreflang="x-default" href="${escapeXml(url.xDefault)}"/>`,
      "  </url>",
    ]),
    "</urlset>",
    "",
  ].join("\n");

  return new Response(body, {
    headers: { "Content-Type": "application/xml; charset=utf-8" },
  });
}
