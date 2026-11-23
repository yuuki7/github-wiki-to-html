import site from "../../site.json";
import {
  articlePageData,
  getEntries,
  renderEntry,
  specialPage,
} from "./content";
import { escapeHtml } from "./html";
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
async function footerHtml(
  entries: PageEntry[],
  lang: string,
  editSlug: string,
  editLabel: string,
): Promise<string> {
  const fragment = specialPage(entries, "_Footer", lang, defaultLanguage);
  const html = fragment ? (await renderEntry(fragment)).html : "";
  return (
    html +
    `<a href="${site.wiki_url}/${escapeUrlPath(editSlug)}">${escapeHtml(editLabel)}</a>`
  );
}

export interface HomePageData {
  ui: UiStrings;
  languageLinks: AlternateLink[];
  canonical: string;
  xDefaultHref: string;
  listedEntries: ArticleEntry[];
  footerHtml: string;
  bodyHtml: string;
}

// One language's home page: the article list for its sidebar,
// its own body (the Home special page), and its footer — its
// edit link names the original's language when the home page
// is itself a translation.
export async function homePageData(lang: string): Promise<HomePageData> {
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
    .sort((a, b) => b.data.creation_date.localeCompare(a.data.creation_date));

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
    footerHtml: await footerHtml(entries, lang, "Home", editLabel),
    bodyHtml: home ? (await renderEntry(home)).html : "",
  };
}

export interface ArticlePageDataFull {
  ui: UiStrings;
  isRedirect: boolean;
  articleLinks: AlternateLink[];
  targetHref: string | undefined;
  canonical: string;
  meta: ArticleMetaProps | undefined;
  xDefaultHref: string | undefined;
  footerHtml: string;
  bodyHtml: string;
  headings: Heading[];
}

// One article page. A redirect entry carries no page of its
// own — the caller renders the stub instead — so for one,
// only the redirect's own fields are filled.
export async function articlePageDataFull(
  entry: PageEntry,
  lang: string,
): Promise<ArticlePageDataFull> {
  const entries = getEntries();
  const ui = uiFor(lang);
  const base = articlePageData(entry, entries, lang);

  if (base.isRedirect || entry.data.kind !== "article") {
    return {
      ui,
      isRedirect: true,
      articleLinks: base.articleLinks,
      targetHref: base.targetHref,
      canonical: "",
      meta: undefined,
      xDefaultHref: undefined,
      footerHtml: "",
      bodyHtml: "",
      headings: [],
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
    targetHref: undefined,
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
    footerHtml: await footerHtml(entries, lang, entry.data.slug, editLabel),
    bodyHtml: rendered.html,
    headings: rendered.headings,
  };
}
