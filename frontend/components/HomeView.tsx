import site from "../../site.json";
import { homePageData } from "../lib/page-data";

// One language's home page: its article, inside the shell
// its layout renders. The head and the shell — the article
// list in the left sidebar, the footer — are the layout's,
// assembled from the same data (lib/page-data.ts).

export default async function HomeView({ lang }: { lang: string }) {
  const data = await homePageData(lang);
  return (
    <article className="article">
      <header className="article__header">
        <h1 className="article__title">{site.name}</h1>
      </header>

      <div className="article__main">{data.body}</div>
    </article>
  );
}
