import site from "../../site.json";
import {
  articlePageData,
  getEntries,
  renderEntry,
  specialPage,
} from "../lib/content";
import { escapeHtml } from "../lib/html";
import {
  absoluteUrl,
  defaultLanguage,
  escapeUrlPath,
  languageNameInNominative,
  pageHref,
  uiFor,
} from "../lib/i18n";
import type { PageEntry } from "../lib/types";
import AiAssistant from "./AiAssistant";
import Page from "./Page";
import RedirectStub from "./RedirectStub";
import Toc from "./Toc";

// One article page, or one redirect stub. `lang` is the language
// the page is served for: the article's own language, or, for a
// redirect (which carries no language), its directory's language.

export default async function ArticleView({
  entry,
  lang,
}: {
  entry: PageEntry;
  lang: string;
}) {
  const entries = getEntries();
  const {
    isRedirect,
    originalLanguage,
    articleLinks,
    targetHref,
    isTranslation,
  } = articlePageData(entry, entries, lang);

  if (isRedirect) {
    return (
      <RedirectStub
        title={entry.data.title}
        language={lang}
        targetHref={targetHref!}
      />
    );
  }
  if (entry.data.kind !== "article") {
    throw new Error(`${entry.id}: not an article or a redirect`);
  }

  // The footer in this page's language, falling back to the site's
  // default language when the footer has not been translated.
  const footerFragment = specialPage(entries, "_Footer", lang, defaultLanguage);
  const footerHtml = footerFragment
    ? (await renderEntry(footerFragment)).html
    : "";

  const ui = uiFor(lang);
  const rendered = await renderEntry(entry);

  // The footer's edit link: a translation's names the language
  // its original is written in.
  const editLabel = isTranslation
    ? ui.editPageFrom(languageNameInNominative(lang, originalLanguage ?? lang))
    : ui.editPage;
  const footer =
    footerHtml +
    `<a href="${site.wiki_url}/${escapeUrlPath(entry.data.slug)}">${escapeHtml(editLabel)}</a>`;

  return (
    <Page
      title={entry.data.title}
      language={entry.data.language}
      languageLinks={articleLinks}
      canonical={absoluteUrl(
        pageHref(lang, entry.data.slug, entry.data.translation ?? false),
      )}
      ogType="article"
      meta={{
        author: entry.data.author,
        creationDate: entry.data.creation_date,
        modifiedDate: entry.data.modified_date,
        language: entry.data.language,
        ...(isTranslation
          ? {
              translation: {
                originalLanguage: originalLanguage ?? lang,
                originalHref: pageHref(
                  originalLanguage ?? lang,
                  entry.data.slug,
                ),
              },
            }
          : {}),
      }}
      headExtra={
        originalLanguage ? (
          <link
            rel="alternate"
            hrefLang="x-default"
            href={absoluteUrl(pageHref(originalLanguage, entry.data.slug))}
          />
        ) : null
      }
      leftSidebar={<Toc headings={rendered.headings} />}
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
      bodyHtml={rendered.html}
      footerHtml={footer}
    />
  );
}
