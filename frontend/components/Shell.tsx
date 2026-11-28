import type { ReactNode } from "react";
import site from "../../site.json";
import { homeHref } from "../lib/i18n";
import type { FooterData } from "../lib/page-data";
import type { AiStrings, AlternateLink, SidebarMenuData } from "../lib/types";
import AiAssistant from "./AiAssistant";
import LanguageMenu from "./LanguageMenu";
import BottomBar from "./BottomBar";
import CodeCopy from "./CodeCopy";
import LinkInterceptor from "./link-interceptor";
import TocDrawer from "./TocDrawer";

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
// region, at every width — holding the page's menu as a
// plain list: on a wide screen the menu is a plain sidebar
// there. Where the menu is not in the layout — on a narrow
// screen, and on a wide one while the AI panel stands —
// the same menu opens as a drawer over the page: the frame
// renders it from the same content carried as data (see
// TocDrawer), worked by the bottom bar's Contents button
// on a narrow screen and by the article title's own button
// (see TocToggle) while the panel stands. The aside
// carries the menu's names as its data attributes, so the
// swap can hand the drawer each page's menu whole (see the
// link interceptor's swap). A page whose sidebar would be
// empty — an article with no headings for its table of
// contents — passes no content, and the aside stays empty,
// rather than holding a menu that opens onto nothing.
//
// The bottom bar stands after the grid's regions: the
// stylesheet shows it only on a narrow screen, where it
// holds in one bar the controls a wide screen spreads
// over the page.

type Props = {
  language: string;
  languageLinks?: AlternateLink[];
  isHome?: boolean;
  className?: string;
  aiStrings: AiStrings;
  leftSidebar?: ReactNode;
  sidebarMenu?: SidebarMenuData | null;
  leftSidebarLabel: string;
  leftSidebarCloseLabel: string;
  homeLabel: string;
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
  sidebarMenu,
  leftSidebarLabel,
  leftSidebarCloseLabel,
  homeLabel,
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
              <LanguageMenu
                language={language}
                languageLinks={languageLinks}
                isHome={isHome ?? false}
              />
            )}
          </nav>
        </header>

        <aside
          className="left-sidebar"
          data-contents-label={leftSidebarLabel}
          data-close-label={leftSidebarCloseLabel}
        >
          {leftSidebar}
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

      <BottomBar
        homeHref={homeHref(language)}
        homeLabel={homeLabel}
        contentsLabel={leftSidebarLabel}
        homeCurrent={!!isHome}
      />
      <LinkInterceptor />
      <CodeCopy />
      <TocDrawer initialData={sidebarMenu ?? null} />
    </>
  );
}
