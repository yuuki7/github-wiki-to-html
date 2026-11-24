import { assertComplete, getEntries } from "./content";
import { defaultLanguage, pageHref, supportedLanguages } from "./i18n";
import type { ArticleEntry, PageEntry } from "./types";
import site from "../../site.json";

// The site's route table: every URL the site serves, and what
// is served there — a home page, an article page, or a stub
// that redirects to a page. The table is the one place the
// URL scheme lives; the app directory only asks it which
// paths a language's pages are and what a path serves.

export type Route =
  | { type: "home"; lang: string }
  | { type: "article"; entry: PageEntry; lang: string }
  | { type: "stub"; title: string; lang: string; redirectTo: string };

function isOriginalArticle(entry: PageEntry): entry is ArticleEntry {
  return entry.data.kind === "article" && !entry.data.translation;
}

let tableCache: ReadonlyMap<string, Route> | null = null;

export function routeTable(): ReadonlyMap<string, Route> {
  if (tableCache) return tableCache;
  const entries = getEntries();

  // Refuse to build while any page lacks a version in some
  // language; missingVersions in i18n.ts states the rule.
  assertComplete(entries);

  const table = new Map<string, Route>();
  const key = (segments: string[]): string => segments.join("/");
  const addRoute = (segments: string[], route: Route, source: string): void => {
    const path = key(segments);
    const previous = table.get(path);
    if (previous) {
      throw new Error(
        `route collision at /${path}: ${describeRoute(previous)} conflicts with ${source}`,
      );
    }
    table.set(path, route);
  };

  const originalsBySlug = new Map<string, ArticleEntry>();
  for (const entry of entries) {
    if (isOriginalArticle(entry)) originalsBySlug.set(entry.data.slug, entry);
  }

  for (const entry of entries) {
    if (entry.data.kind === "article") {
      if (entry.data.translation) {
        // A translation lives under its language.
        addRoute(
          [entry.data.language, entry.data.slug],
          {
            type: "article",
            entry,
            lang: entry.data.language,
          },
          entry.filePath,
        );
      } else {
        // An original lives at the root. The same article addressed
        // with its original language's code redirects to the
        // code-less URL.
        addRoute(
          [entry.data.slug],
          {
            type: "article",
            entry,
            lang: entry.data.language,
          },
          entry.filePath,
        );
        addRoute(
          [entry.data.language, entry.data.slug],
          {
            type: "stub",
            title: entry.data.title,
            lang: entry.data.language,
            redirectTo: pageHref(entry.data.language, entry.data.slug),
          },
          `${entry.filePath} language redirect`,
        );
      }
    }
  }

  // The homes: the default language's at the root, every other
  // language's under its code. Every language the site declares
  // gets a home page, whether or not it has any page yet; the
  // list comes from site.json (via i18n's supportedLanguages),
  // never from the content itself. A home is set after the
  // articles, so it wins its single-segment path the way the
  // more specific route did under the old templates.
  // Home routes are reserved and intentionally take precedence over
  // a one-segment article whose slug equals a language code.
  table.set(key([]), { type: "home", lang: defaultLanguage });
  for (const lang of supportedLanguages) {
    if (lang !== defaultLanguage) {
      table.set(key([lang]), { type: "home", lang });
    }
  }

  // The default language's home addressed with its code
  // redirects to the root.
  table.set(key([defaultLanguage]), {
    type: "stub",
    title: site.name,
    lang: defaultLanguage,
    redirectTo: "/",
  });

  // The redirects, last: a redirect claims only the paths no
  // page or home already serves, because the existing page
  // always wins over a redirect. A redirect carries the
  // language its target's body had under the old name, and the
  // root form of the old URL serves that language's version of
  // the target — the old URL named that language's page. That
  // version exists when the old name's language is the
  // target's own or one the site declares; otherwise the root
  // form serves the target's original, the successor of the
  // old page itself. The old name's forms in the other declared
  // languages serve those languages' versions.
  for (const entry of entries) {
    if (entry.data.kind !== "redirect") continue;
    const { slug, language: own } = entry.data;
    const original = originalsBySlug.get(entry.data.target_slug);
    if (!original) {
      throw new Error(
        `${entry.filePath}: redirect target ${entry.data.target_slug} has no original article`,
      );
    }
    const rootLang =
      original &&
      (own === original.data.language || supportedLanguages.includes(own))
        ? own
        : (original?.data.language ?? own);
    if (!table.has(key([slug]))) {
      addRoute(
        [slug],
        { type: "article", entry, lang: rootLang },
        entry.filePath,
      );
    }
    if (!table.has(key([rootLang, slug]))) {
      // The old name addressed with its own language's code
      // redirects to the code-less form.
      addRoute(
        [rootLang, slug],
        {
          type: "stub",
          title: entry.data.title,
          lang: rootLang,
          redirectTo: pageHref(rootLang, slug),
        },
        `${entry.filePath} language redirect`,
      );
    }
    for (const lang of supportedLanguages) {
      if (lang === rootLang) continue;
      if (!table.has(key([lang, slug]))) {
        addRoute(
          [lang, slug],
          { type: "article", entry, lang },
          entry.filePath,
        );
      }
    }
  }

  tableCache = table;
  return table;
}

function describeRoute(route: Route): string {
  if (route.type === "home") return `${route.lang} home`;
  if (route.type === "article") return route.entry.filePath;
  return `${route.title} redirect`;
}

// The paths served in one language, as segment lists: the
// generateStaticParams of that language's pages.
export function pathsForLanguage(lang: string): string[][] {
  return [...routeTable().entries()]
    .filter(([, route]) => route.lang === lang)
    .map(([path]) => (path === "" ? [] : path.split("/")));
}

// What one path serves, if anything: the one lookup into the
// route table. The table is keyed by
// raw segments, while Next.js hands route params to pages and
// layouts still percent-encoded, so decode each segment here —
// exactly once, at this boundary. Callers pass the params as
// they received them.
export function routeFor(encodedSegments: string[]): Route | undefined {
  const segments = encodedSegments.map((segment) =>
    decodeURIComponent(segment),
  );
  return routeTable().get(segments.join("/"));
}
