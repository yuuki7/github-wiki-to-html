import type { ReactNode } from "react";
import site from "../../site.json";
import { getEntries, renderEntry, specialPage } from "./content";
import {
  absoluteUrl,
  defaultLanguage,
  escapeUrlPath,
  homeHref,
  languageNameInNominative,
  pageHref,
  supportedLanguages,
  uiFor,
  type UiStrings,
} from "./i18n";
import type { Heading } from "./markdown";
import type {
  AlternateLink,
  ArticleEntry,
  ArticleMetaProps,
  PageEntry,
} from "./types";

// The data one page is assembled from, shared by the two
// places that render a page: the layout, which renders the
// head and the shell (the header, the sidebars, the footer)
// around the page, and the page itself, which renders only
// the article. Everything here is a pure function of the
// content collection, so the two renders cannot disagree
// about what page they are rendering.

// The page's footer: its footer fragment in the page's
// language, falling back to the site's default language when
// the fragment has not been translated, and the edit link
// that closes every page.
export interface FooterData {
  body: ReactNode;
  editHref: string;
  editLabel: string;
}

async function footerData(
  entries: PageEntry[],
  lang: string,
  editSlug: string,
  editLabel: string,
): Promise<FooterData> {
  const fragment = specialPage(entries, "_Footer", lang, defaultLanguage);
  return {
    body: fragment ? (await renderEntry(fragment)).body : undefined,
    editHref: `${site.wiki_url}/${escapeUrlPath(editSlug)}`,
    editLabel,
  };
}

export interface HomePageData {
  ui: UiStrings;
  languageLinks: AlternateLink[];
  canonical: string;
  xDefaultHref: string;
  listedEntries: ArticleEntry[];
  footer: FooterData;
  body: ReactNode;
}

// One language's home page: the article list for its sidebar,
// its own body (the Home special page), and its footer — its
// edit link names the original's language when the home page
// is itself a translation.
async function computeHomePageData(lang: string): Promise<HomePageData> {
  const entries = getEntries();
  const ui = uiFor(lang);

  const home = entries.find(
    (f) =>
      f.data.kind === "special" &&
      f.data.slug === "Home" &&
      f.data.language === lang,
  );

  const listedEntries = entries
    .filter(
      (p): p is ArticleEntry =>
        p.data.kind === "article" &&
        p.data.language === lang &&
        (p.data.listed ?? true),
    )
    .sort((a, b) =>
      Temporal.Instant.compare(b.data.creation_date, a.data.creation_date),
    );

  // The other languages' home pages, for the switcher and
  // hreflang: the site's declared languages, in site.json order.
  const languageLinks = supportedLanguages.map((language) => ({
    language,
    href: homeHref(language),
  }));

  const editLabel =
    lang === defaultLanguage
      ? ui.editPage
      : ui.editPageFrom(languageNameInNominative(lang, defaultLanguage));

  return {
    ui,
    languageLinks,
    canonical: absoluteUrl(homeHref(lang)),
    xDefaultHref: absoluteUrl(homeHref(site.language)),
    listedEntries,
    footer: await footerData(entries, lang, "Home", editLabel),
    body: home ? (await renderEntry(home)).body : undefined,
  };
}

export type ArticlePageDataFull =
  | {
      isRedirect: true;
      targetHref: string;
    }
  | {
      ui: UiStrings;
      isRedirect: false;
      articleLinks: AlternateLink[];
      canonical: string;
      meta: ArticleMetaProps;
      xDefaultHref: string | undefined;
      footer: FooterData;
      body: ReactNode;
      headings: Heading[];
    };

// The language relationships one article entry carries, derived
// from itself and the whole collection: the original language,
// this page in every supported language, and — for a redirect —
// the target in the language the stub serves. Pure data, so the
// layout and the page can both use it without rendering first.
function articlePageData(
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

  // An original's own language is the one it is written in; a
  // translation names the language it was written from.
  const originalLanguage =
    entry.data.kind === "article"
      ? (entry.data.original_language ?? entry.data.language)
      : undefined;

  // The original lives at the root, every translation under its
  // language code. The same list serves the switcher and
  // hreflang, so the two cannot disagree.
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

  return {
    isRedirect,
    originalLanguage,
    articleLinks,
    targetHref,
    isTranslation:
      entry.data.kind === "article" && (entry.data.translation ?? false),
  };
}

// One article page. A redirect entry carries no page of its
// own — the caller renders the stub instead — so for one,
// only the redirect's own fields are filled.
async function computeArticlePageDataFull(
  entry: PageEntry,
  lang: string,
): Promise<ArticlePageDataFull> {
  const entries = getEntries();
  const ui = uiFor(lang);
  const base = articlePageData(entry, entries, lang);

  if (base.isRedirect || entry.data.kind !== "article") {
    // A redirect's entry always names its target — the schema
    // requires target_slug — so its href is always here, and
    // the callers turn every other non-article entry away
    // before asking. Anything else reaching this branch is a
    // broken entry: fail, rather than invent a destination
    // for the reader.
    const targetHref = base.targetHref;
    if (targetHref === undefined) {
      throw new Error(
        `${entry.id}: non-article entry without a redirect target`,
      );
    }
    return {
      isRedirect: true,
      targetHref,
    };
  }

  const rendered = await renderEntry(entry);

  // The footer's edit link: a translation's names the language
  // its original is written in.
  const editLabel = base.isTranslation
    ? ui.editPageFrom(
        languageNameInNominative(lang, base.originalLanguage ?? lang),
      )
    : ui.editPage;

  return {
    ui,
    isRedirect: false,
    articleLinks: base.articleLinks,
    canonical: absoluteUrl(
      pageHref(lang, entry.data.slug, entry.data.translation ?? false),
    ),
    meta: {
      author: entry.data.author,
      creationDate: entry.data.creation_date,
      modifiedDate: entry.data.modified_date,
      language: entry.data.language,
      ...(base.isTranslation
        ? {
            translation: {
              originalLanguage: base.originalLanguage ?? lang,
              originalHref: pageHref(
                base.originalLanguage ?? lang,
                entry.data.slug,
              ),
            },
          }
        : {}),
    },
    xDefaultHref: base.originalLanguage
      ? absoluteUrl(pageHref(base.originalLanguage, entry.data.slug))
      : undefined,
    footer: await footerData(entries, lang, entry.data.slug, editLabel),
    body: rendered.body,
    headings: rendered.headings,
  };
}

// A layout and the page it frames ask for the same data. Cache the
// promise so the second caller cannot render the page's Markdown a
// second time or disagree with the first about its language strings.

const homeCache = new Map<string, Promise<HomePageData>>();
const articleCache = new Map<string, Promise<ArticlePageDataFull>>();

export function homePageData(lang: string): Promise<HomePageData> {
  let data = homeCache.get(lang);
  if (!data) {
    data = computeHomePageData(lang);
    homeCache.set(lang, data);
  }
  return data;
}

export function articlePageDataFull(
  entry: PageEntry,
  lang: string,
): Promise<ArticlePageDataFull> {
  const key = `${lang}/${entry.id}`;
  let data = articleCache.get(key);
  if (!data) {
    data = computeArticlePageDataFull(entry, lang);
    articleCache.set(key, data);
  }
  return data;
}
