import { pageHref, supportedLanguages } from "./i18n";
import type { AlternateLink, ArticleEntry, PageEntry } from "./types";

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
