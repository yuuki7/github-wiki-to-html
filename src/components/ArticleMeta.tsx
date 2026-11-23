import { defaultLanguage, languageNameIn, uiFor } from "../lib/i18n";
import type { ArticleMetaProps } from "../lib/types";

// An article's byline: its author, its creation and last
// modification dates, and, for a translation, the note that
// says so, with a link to the original.

export default function ArticleMeta({
  author,
  creationDate,
  modifiedDate,
  language,
  translation,
}: ArticleMetaProps) {
  const locale = language ?? defaultLanguage;

  const dateFmt = new Intl.DateTimeFormat(locale, {
    timeZone: "UTC",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const timeFmt = new Intl.DateTimeFormat(locale, {
    timeZone: "UTC",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });

  // A date is shown as the date alone, and the ISO form is in
  // its title. The one exception is an article created and last
  // modified on the same day: the two dates would read
  // identically, so both carry their time as well.
  const utcDay = (iso: string) => {
    const d = new Date(iso);
    return `${d.getUTCFullYear()}-${d.getUTCMonth()}-${d.getUTCDate()}`;
  };
  const showModified =
    modifiedDate !== undefined && modifiedDate !== creationDate;
  const sameDay = showModified && utcDay(modifiedDate) === utcDay(creationDate);
  const formatDate = (iso: string) => dateFmt.format(new Date(iso));
  const formatFull = (iso: string) =>
    `${dateFmt.format(new Date(iso))} ${timeFmt.format(new Date(iso))}`;
  const format = (iso: string) => (sameDay ? formatFull(iso) : formatDate(iso));

  return (
    <>
      <p className="article__meta">
        <span className="article__author">
          {uiFor(locale).byline} {author}
        </span>
        {" · "}
        <time
          className="article__date article__date--created"
          dateTime={creationDate}
          title={creationDate}
        >
          {format(creationDate)}
        </time>
        {showModified && (
          <>
            {" · "}
            <time
              className="article__date article__date--modified"
              dateTime={modifiedDate}
              title={modifiedDate}
            >
              {format(modifiedDate)}
            </time>
          </>
        )}
      </p>

      {translation && (
        <p className="article__meta article__meta--translation">
          {uiFor(locale).translationNotice(
            languageNameIn(locale, translation.originalLanguage),
          )}{" "}
          <a href={translation.originalHref}>{uiFor(locale).originalArticle}</a>
        </p>
      )}
    </>
  );
}
