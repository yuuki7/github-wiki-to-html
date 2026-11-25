import type { ReactNode } from "react";
import site from "../../site.json";
import { homeHref, languageName } from "../lib/i18n";
import type { FooterData } from "../lib/page-data";
import type { AiStrings, AlternateLink } from "../lib/types";
import AiAssistant from "./AiAssistant";
import CodeCopy from "./CodeCopy";
import LinkInterceptor from "./link-interceptor";
import MenuDismiss from "./MenuDismiss";

// The shell of the app: everything around the article — the
// scripts, the header with the language switcher, the two
// sidebars, and the footer, in the page grid the stylesheet
// lays out. The layouts render it, not the pages, so it is
// rendered once and stays in place while the reader moves
// between pages: in-app navigation replaces only the article
// the shell frames, and what the reader has in the shell —
// a half-typed question to the AI assistant above all — is
// not thrown away by moving.
//
// The regions sit in a wrapper that takes the body's grid
// over unchanged (display: contents in the stylesheet): the
// grid's items stay the header, the sidebars, the main
// column, and the footer, and the wrapper only carries the
// page's class, which the document's <body> cannot be given
// per page in this framework.
//
// The left sidebar is an <aside> — the page's complementary
// region, at every width — holding a <details>: on a narrow
// screen the menu's summary is its one control, and the
// menu sits before the article, closed; on a wide screen
// the stylesheet shows no summary and keeps the content
// always visible, so the menu is a plain sidebar there. A
// page whose sidebar would be empty — an article with no
// headings for its table of contents — passes no content,
// and the aside stays empty, rather than holding a menu
// that opens onto nothing.

type Props = {
  language: string;
  languageLinks?: AlternateLink[];
  isHome?: boolean;
  className?: string;
  aiStrings: AiStrings;
  leftSidebar?: ReactNode;
  leftSidebarLabel?: string;
  footer: FooterData;
  children: ReactNode;
};

export default function Shell({
  language,
  languageLinks,
  isHome,
  className,
  aiStrings,
  leftSidebar,
  leftSidebarLabel,
  footer,
  children,
}: Props) {
  return (
    <>
      <script defer src="/assets/js/mathjax-config.js" />
      <script
        defer
        src="https://cdn.jsdelivr.net/npm/mathjax@4.1.2/startup.js"
        integrity="sha512-hWGDmsdTVDhEQ++tRfdduyZoXByJaAEMAGK3i/5dphjQrNplBhzLYHQIwR3ZqXH74uE1y5DNFpGNXQqWYhiUOQ=="
        crossOrigin="anonymous"
      />

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

        <aside className="left-sidebar">
          {leftSidebar && (
            <details>
              <summary>
                <svg
                  className="left-sidebar__icon left-sidebar__icon--menu"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                  aria-hidden="true"
                >
                  <path d="M4 7h16M4 12h10M4 17h13" />
                </svg>
                <svg
                  className="left-sidebar__icon left-sidebar__icon--close"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                  aria-hidden="true"
                >
                  <path d="M18 6 6 18M6 6l12 12" />
                </svg>
                {leftSidebarLabel}
              </summary>
              {leftSidebar}
            </details>
          )}
        </aside>

        <main className="main">{children}</main>

        <aside className="right-sidebar">
          <AiAssistant strings={aiStrings} />
        </aside>

        <footer className="footer">
          {footer.body}
          <a href={footer.editHref}>{footer.editLabel}</a>
        </footer>
      </div>

      <LinkInterceptor />
      <CodeCopy />
      <MenuDismiss />
    </>
  );
}
