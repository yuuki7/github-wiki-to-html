import site from "../../site.json";
import { getEntries, renderEntry, specialPage } from "../lib/content";
import { escapeHtml } from "../lib/html";
import {
  absoluteUrl,
  defaultLanguage,
  escapeUrlPath,
  homeHref,
  languageNameInNominative,
  pageHref,
  supportedLanguages,
  uiFor,
} from "../lib/i18n";
import type { ArticleEntry } from "../lib/types";
import AiAssistant from "./AiAssistant";
import Page from "./Page";

// One language's home page, listing that language's articles.

export default async function HomeView({ lang }: { lang: string }) {
  const pages = getEntries();

  const home = pages.find(
    (f) =>
      f.data.kind === "special" &&
      f.data.slug === "Home" &&
      f.data.language === lang,
  );
  const footer = specialPage(pages, "_Footer", lang, defaultLanguage);

  const listedPages = pages
    .filter(
      (p): p is ArticleEntry =>
        p.data.kind === "article" &&
        p.data.language === lang &&
        (p.data.listed ?? true),
    )
    .sort((a, b) => b.data.creation_date.localeCompare(a.data.creation_date));

  // The other languages' home pages, for the switcher and hreflang:
  // the site's declared languages, in site.json order.
  const languageLinks = supportedLanguages.map((language) => ({
    language,
    href: homeHref(language),
  }));

  const ui = uiFor(lang);

  const homeHtml = home ? (await renderEntry(home)).html : "";
  const footerHtml = footer ? (await renderEntry(footer)).html : "";
  const editLabel =
    lang === defaultLanguage
      ? ui.editPage
      : ui.editPageFrom(languageNameInNominative(lang, defaultLanguage));
  const footerWithEdit =
    footerHtml +
    `<a href="${site.wiki_url}/${escapeUrlPath("Home")}">${escapeHtml(editLabel)}</a>`;

  return (
    <Page
      className="home"
      title={site.name}
      language={lang}
      isHome
      languageLinks={languageLinks}
      canonical={absoluteUrl(homeHref(lang))}
      ogType="website"
      headExtra={
        <link
          rel="alternate"
          hrefLang="x-default"
          href={absoluteUrl(homeHref(site.language))}
        />
      }
      leftSidebar={
        <ul>
          {listedPages.map((entry) => (
            <li key={entry.id}>
              <a
                href={pageHref(
                  lang,
                  entry.data.slug,
                  entry.data.translation ?? false,
                )}
              >
                {entry.data.title}
              </a>
            </li>
          ))}
        </ul>
      }
      rightSidebar={
        <AiAssistant
          strings={{
            summarize: ui.aiSummarize,
            loading: ui.aiLoading,
            send: ui.aiSend,
            unsupported: ui.aiUnsupported,
            error: ui.aiError,
          }}
        />
      }
      bodyHtml={homeHtml}
      footerHtml={footerWithEdit}
    />
  );
}
