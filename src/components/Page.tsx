import type { ReactNode } from "react";
import site from "../../site.json";
import { homeHref, languageName } from "../lib/i18n";
import type { ArticleProps } from "../lib/types";
import ArticleMeta from "./ArticleMeta";
import BaseHead from "./BaseHead";
import CodeCopy from "./CodeCopy";
import LinkInterceptor from "./LinkInterceptor";

// One page of the site: the head, the header with the
// language switcher, the two sidebars, the article, and the
// footer, in the page grid the stylesheet lays out. The
// regions are props — the views fill them — and the article
// body and the footer arrive as HTML, rendered from the
// content at build time.
//
// The regions sit in a wrapper that takes the body's grid
// over unchanged (display: contents in the stylesheet): the
// grid's items stay the header, the sidebars, the main
// column, and the footer, and the wrapper only carries the
// page's class, which the document's <body> cannot be given
// per page in this framework.

type Props = ArticleProps & {
  headExtra?: ReactNode;
  leftSidebar?: ReactNode;
  rightSidebar?: ReactNode;
  bodyHtml: string;
  footerHtml: string;
};

export default function Page({
  title,
  isHome,
  meta,
  language,
  className,
  languageLinks,
  canonical,
  ogType,
  scripts = true,
  headExtra,
  leftSidebar,
  rightSidebar,
  bodyHtml,
  footerHtml,
}: Props) {
  return (
    <>
      <BaseHead
        title={title}
        language={language}
        alternates={languageLinks}
        canonical={canonical}
        ogType={ogType}
        meta={meta}
        isHome={isHome}
      >
        {headExtra}
      </BaseHead>
      {scripts && (
        <>
          <script defer src="/assets/js/mathjax-config.js" />
          <script
            defer
            src="https://cdn.jsdelivr.net/npm/mathjax@4.1.2/startup.js"
            integrity="sha512-hWGDmsdTVDhEQ++tRfdduyZoXByJaAEMAGK3i/5dphjQrNplBhzLYHQIwR3ZqXH74uE1y5DNFpGNXQqWYhiUOQ=="
            crossOrigin="anonymous"
          />
        </>
      )}

      <div className={className ? `page-root ${className}` : "page-root"}>
        <header className="header">
          <nav>
            {!isHome && <a href={homeHref(language)}>{site.name}</a>}
            {languageLinks && languageLinks.length > 1 && (
              <div className="language-menu">
                <button
                  type="button"
                  className="language-menu__button"
                  popoverTarget="language-switcher"
                >
                  <span aria-hidden="true">🌐</span> {languageName(language)}
                </button>
                <ul
                  className="language-menu__panel"
                  id="language-switcher"
                  popover="auto"
                >
                  {languageLinks.map((link) => (
                    <li key={link.language}>
                      {link.language === language ? (
                        <span aria-current="true">
                          {languageName(link.language)}
                        </span>
                      ) : (
                        <a
                          href={link.href}
                          hrefLang={link.language}
                          lang={link.language}
                        >
                          {languageName(link.language)}
                        </a>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </nav>
        </header>

        <aside className="left-sidebar">{leftSidebar}</aside>

        <main className="main">
          <article className="article">
            <header className="article__header">
              <h1 className="article__title">{title}</h1>
              {!isHome && meta && <ArticleMeta {...meta} />}
            </header>

            <div
              className="article__main"
              dangerouslySetInnerHTML={{ __html: bodyHtml }}
            />
          </article>
        </main>

        <aside className="right-sidebar">{rightSidebar}</aside>

        <footer
          className="footer"
          dangerouslySetInnerHTML={{ __html: footerHtml }}
        />
      </div>

      <LinkInterceptor />
      <CodeCopy />
    </>
  );
}
