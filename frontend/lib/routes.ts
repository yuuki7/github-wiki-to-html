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

let tableCache: Map<string, Route> | null = null;

export function routeTable(): Map<string, Route> {
  if (tableCache) return tableCache;
  const entries = getEntries();

  // Refuse to build while any page lacks a version in some
  // language; missingVersions in i18n.ts states the rule.
  assertComplete(entries);

  const table = new Map<string, Route>();
  const key = (segments: string[]): string => segments.join("/");

  // A redirect carries no language of its own; the language it
  // serves is the directory its file lives in.
  const directoryLanguage = (entry: PageEntry): string => {
    const parts = entry.filePath.split("/");
    return parts.length > 1
      ? (parts[parts.length - 2] ?? defaultLanguage)
      : defaultLanguage;
  };
  const originalOf = (slug: string) =>
    entries.find(
      (e): e is ArticleEntry =>
        e.data.kind === "article" &&
        e.data.slug === slug &&
        !e.data.translation,
    );

  for (const entry of entries) {
    if (entry.data.kind === "article") {
      if (entry.data.translation) {
        // A translation lives under its language.
        table.set(key([entry.data.language, entry.data.slug]), {
          type: "article",
          entry,
          lang: entry.data.language,
        });
      } else {
        // An original lives at the root. The same article addressed
        // with its original language's code redirects to the
        // code-less URL.
        table.set(key([entry.data.slug]), {
          type: "article",
          entry,
          lang: entry.data.language,
        });
        table.set(key([entry.data.language, entry.data.slug]), {
          type: "stub",
          title: entry.data.title,
          lang: entry.data.language,
          redirectTo: pageHref(entry.data.language, entry.data.slug),
        });
      }
    } else if (entry.data.kind === "redirect") {
      // A redirect is served at the root in its target's original
      // language, and under its directory's language elsewhere.
      const lang = directoryLanguage(entry);
      const original = originalOf(entry.data.target_slug);
      if (original && original.data.language === lang) {
        table.set(key([entry.data.slug]), { type: "article", entry, lang });
        // The alias addressed with its language's code redirects
        // to the code-less alias.
        table.set(key([lang, entry.data.slug]), {
          type: "stub",
          title: entry.data.title,
          lang,
          redirectTo: pageHref(lang, entry.data.slug),
        });
      } else {
        table.set(key([lang, entry.data.slug]), {
          type: "article",
          entry,
          lang,
        });
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

  tableCache = table;
  return table;
}

// The paths served in one language, as segment lists: the
// generateStaticParams of that language's pages.
export function pathsForLanguage(lang: string): string[][] {
  return [...routeTable().entries()]
    .filter(([, route]) => route.lang === lang)
    .map(([path]) => (path === "" ? [] : path.split("/")));
}

// What one path serves, if anything.
export function routeFor(segments: string[]): Route | undefined {
  return routeTable().get(segments.join("/"));
}
