import { articlePageDataFull } from "../lib/page-data";
import type { PageEntry } from "../lib/types";
import ArticleMeta from "./ArticleMeta";
import RedirectStub from "./RedirectStub";

// One article page, or one redirect stub. `lang` is the language
// the page is served for: the article's own language, or, for a
// redirect (which carries no language), its directory's language.
//
// An article renders only itself; the head and the shell —
// the table of contents in the left sidebar, the footer —
// are its layout's, assembled from the same data
// (lib/page-data.ts). A redirect renders its stub, which the
// layout leaves bare.

export default async function ArticleView({
  entry,
  lang,
}: {
  entry: PageEntry;
  lang: string;
}) {
  if (entry.data.kind !== "article" && entry.data.kind !== "redirect") {
    throw new Error(`${entry.id}: not an article or a redirect`);
  }

  const data = await articlePageDataFull(entry, lang);

  if (data.isRedirect) {
    return (
      <RedirectStub
        title={entry.data.title}
        language={lang}
        targetHref={data.targetHref}
      />
    );
  }

  return (
    <article className="article">
      <header className="article__header">
        <h1 className="article__title">{entry.data.title}</h1>
        <ArticleMeta {...data.meta} />
      </header>

      <div className="article__main">{data.body}</div>
    </article>
  );
}
