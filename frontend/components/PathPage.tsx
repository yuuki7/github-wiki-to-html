import { notFound } from "next/navigation";
import { pathsForLanguage, routeFor } from "../lib/routes";
import ArticleView from "./ArticleView";
import HomeView from "./HomeView";
import RedirectStub from "./RedirectStub";

// The one page component behind every route: it asks the
// route table (lib/routes.ts) what a path serves and renders
// that. Each language's app directory re-exports this with
// its own static paths, so that the document's language —
// set by that directory's layout — is the page's language.

export { pathsForLanguage };

export default async function PathPage({ segments }: { segments: string[] }) {
  // Next.js decodes dynamic route params before passing them
  // to the page. Decode them again and a literal '%' in a wiki
  // slug can throw or resolve to a different route.
  const route = routeFor(segments);
  if (!route) notFound();
  switch (route.type) {
    case "home":
      return <HomeView lang={route.lang} />;
    case "article":
      return <ArticleView entry={route.entry} lang={route.lang} />;
    case "stub":
      return (
        <RedirectStub
          title={route.title}
          language={route.lang}
          targetHref={route.redirectTo}
        />
      );
  }
}
