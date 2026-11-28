import type { ReactNode } from "react";
import site from "../../site.json";
import { aiStringsFor, pageHref } from "../lib/i18n";
import { articlePageDataFull, homePageData } from "../lib/page-data";
import { routeFor } from "../lib/routes";
import BaseHead from "./BaseHead";
import Shell from "./Shell";
import Toc, { tocItems } from "./Toc";

// The head and the shell for one route, rendered by the
// layouts: a layout knows its route's segments, so it asks
// the route table what the route serves and frames the page
// accordingly. A page the shell does not frame — a redirect
// stub, which sends the reader elsewhere at once, and the
// not-found page — is rendered bare, exactly as it was when
// the pages framed themselves.

export default async function RouteShell({
  segments,
  children,
}: {
  segments: string[];
  children: ReactNode;
}) {
  // The segments are the route params as Next.js delivered
  // them, still percent-encoded; routeFor decodes them.
  const route = routeFor(segments);
  if (!route || route.type === "stub") return <>{children}</>;

  if (route.type === "home") {
    const data = await homePageData(route.lang);
    const ui = data.ui;
    return (
      <>
        <BaseHead
          title={site.name}
          language={route.lang}
          alternates={data.languageLinks}
          canonical={data.canonical}
          ogType="website"
          isHome
        >
          <link rel="alternate" hrefLang="x-default" href={data.xDefaultHref} />
        </BaseHead>
        <Shell
          language={route.lang}
          languageLinks={data.languageLinks}
          isHome
          className="home"
          aiStrings={aiStringsFor(ui)}
          leftSidebarLabel={ui.contents}
          leftSidebarCloseLabel={ui.close}
          homeLabel={ui.home}
          sidebarMenu={
            data.listedEntries.length > 0
              ? {
                  kind: "list",
                  label: ui.contents,
                  closeLabel: ui.close,
                  items: data.listedEntries.map((entry) => ({
                    href: pageHref(
                      route.lang,
                      entry.data.slug,
                      entry.data.translation ?? false,
                    ),
                    text: entry.data.title,
                  })),
                }
              : null
          }
          leftSidebar={
            data.listedEntries.length > 0 ? (
              <ul>
                {data.listedEntries.map((entry) => (
                  <li key={entry.id}>
                    <a
                      href={pageHref(
                        route.lang,
                        entry.data.slug,
                        entry.data.translation ?? false,
                      )}
                    >
                      {entry.data.title}
                    </a>
                  </li>
                ))}
              </ul>
            ) : undefined
          }
          footer={data.footer}
        >
          {children}
        </Shell>
      </>
    );
  }

  // An article route for a redirect entry serves the entry's
  // stub, which the shell leaves bare, like a stub route.
  if (route.entry.data.kind !== "article") return <>{children}</>;
  const data = await articlePageDataFull(route.entry, route.lang);
  if (data.isRedirect) return <>{children}</>;
  const ui = data.ui;
  return (
    <>
      <BaseHead
        title={route.entry.data.title}
        language={route.entry.data.language}
        alternates={data.articleLinks}
        canonical={data.canonical}
        ogType="article"
        meta={data.meta}
      >
        {data.xDefaultHref && (
          <link rel="alternate" hrefLang="x-default" href={data.xDefaultHref} />
        )}
      </BaseHead>
      <Shell
        language={route.entry.data.language}
        languageLinks={data.articleLinks}
        aiStrings={aiStringsFor(ui)}
        leftSidebarLabel={ui.contents}
        leftSidebarCloseLabel={ui.close}
        homeLabel={ui.home}
        sidebarMenu={
          tocItems(data.headings).length > 0
            ? {
                kind: "toc",
                label: ui.contents,
                closeLabel: ui.close,
                items: tocItems(data.headings).map((heading) => ({
                  href: `#${heading.slug}`,
                  text: heading.text,
                  depth: heading.depth,
                })),
              }
            : null
        }
        leftSidebar={
          tocItems(data.headings).length > 0 ? (
            <Toc headings={data.headings} />
          ) : undefined
        }
        footer={data.footer}
      >
        {children}
      </Shell>
    </>
  );
}
