import { getCollection } from "astro:content";
import {
  absoluteUrl,
  defaultLanguage,
  homeHref,
  pageHref,
  supportedLanguages,
} from "../i18n";

// The site's sitemap: every article in every language, and every
// language's home page. Each URL names its versions in the other
// languages as alternates, with the original as the default.
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

  // Articles, grouped by slug so that each version of an article
  // can name the others.
  const versionsBySlug = new Map<string, typeof entries>();
  for (const entry of entries) {
    if (entry.data.kind !== "article") continue;
    const versions = versionsBySlug.get(entry.data.slug) ?? [];
    versions.push(entry);
    versionsBySlug.set(entry.data.slug, versions);
  }
  for (const [slug, versions] of versionsBySlug) {
    const hrefOf = (version: (typeof entries)[number]): string =>
      absoluteUrl(
        pageHref(
          version.data.language,
          slug,
          version.data.translation ?? false,
        ),
      );
    const alternates = versions.map((version) => ({
      language: version.data.language,
      href: hrefOf(version),
    }));
    const original = versions.find((version) => !version.data.translation);
    const xDefault = original ? hrefOf(original) : alternates[0].href;
    for (const version of versions) {
      urls.push({
        loc: hrefOf(version),
        lastmod: version.data.modified_date ?? version.data.creation_date,
        alternates,
        xDefault,
      });
    }
  }

  // Home pages, one per supported language.
  const homeAlternates = supportedLanguages.map((language) => ({
    language,
    href: absoluteUrl(homeHref(language)),
  }));
  for (const language of supportedLanguages) {
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

  urls.sort((a, b) => a.loc.localeCompare(b.loc));

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
