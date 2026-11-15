import { getCollection } from "astro:content";
import {
  absoluteUrl,
  defaultLanguage,
  homeHref,
  pageHref,
  supportedLanguages,
} from "../i18n";

// The site's sitemap: every language's home page first, then
// every article in every language, newest updated first. Each
// URL names its versions in the other languages as alternates,
// with the original as the default. Redirect stubs are not
// pages and are not listed.

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

  // Home pages, one per supported language. They carry no dates,
  // so they cannot take part in the newest-first order below;
  // they stand at the head, the top page — the default language's
  // home — pinned first, then the others in language order.
  const homeAlternates = supportedLanguages.map((language) => ({
    language,
    href: absoluteUrl(homeHref(language)),
  }));
  const homeLanguages = [
    defaultLanguage,
    ...supportedLanguages.filter((language) => language !== defaultLanguage),
  ];
  for (const language of homeLanguages) {
    const home = entries.find(
      (entry) =>
        entry.data.kind === "special" &&
        entry.data.slug === "Home" &&
        entry.data.language === language,
    );
    urls.push({
      loc: absoluteUrl(homeHref(language)),
      lastmod: home?.data.modified_date ?? home?.data.creation_date,
      alternates: homeAlternates,
      xDefault: absoluteUrl(homeHref(defaultLanguage)),
    });
  }

  // Articles, grouped by slug so that each version of an article
  // can name the others. A translation inherits the original's
  // dates, so a group has one date: the article's last update,
  // or its creation when it was never updated.
  const versionsBySlug = new Map<string, typeof entries>();
  for (const entry of entries) {
    if (entry.data.kind !== "article") continue;
    const versions = versionsBySlug.get(entry.data.slug) ?? [];
    versions.push(entry);
    versionsBySlug.set(entry.data.slug, versions);
  }
  const groups = [...versionsBySlug.entries()].map(([slug, versions]) => {
    const hrefOf = (version: (typeof entries)[number]): string =>
      absoluteUrl(
        pageHref(
          version.data.language,
          slug,
          version.data.translation ?? false,
        ),
      );
    const updated = (version: (typeof entries)[number]): string =>
      version.data.modified_date ?? version.data.creation_date;
    const original = versions.find((version) => !version.data.translation);
    // The original first, then the translations in the site's
    // language order.
    const ordered = [...versions].sort((a, b) => {
      if (!a.data.translation) return -1;
      if (!b.data.translation) return 1;
      return (
        supportedLanguages.indexOf(a.data.language) -
        supportedLanguages.indexOf(b.data.language)
      );
    });
    return {
      slug,
      date: updated(original ?? versions[0]),
      urls: ordered.map(
        (version): SitemapUrl => ({
          loc: hrefOf(version),
          lastmod: updated(version),
          alternates: ordered.map((other) => ({
            language: other.data.language,
            href: hrefOf(other),
          })),
          xDefault: original ? hrefOf(original) : hrefOf(ordered[0]),
        }),
      ),
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
    urls.push(...group.urls);
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
