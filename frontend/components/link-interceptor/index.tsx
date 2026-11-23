"use client";

import { useEffect } from "react";

// In-app navigation for the site's internal links. The site
// is a set of static documents, one per page, and the frame
// around the article — the header, the sidebars, the footer —
// is the app the reader is using: moving to another page
// must no more rebuild the frame than moving between views
// rebuilds an app's chrome. So following an internal link
// fetches the target document and replaces only what the
// page itself changes: the head's page-specific elements,
// the language switcher's links, the left sidebar's
// contents, the article, and the footer's edit link. Every
// other element in the document is left exactly as it is,
// so what the reader has in the frame — a half-typed
// question to the AI assistant, a selection in the sidebar,
// the assistant's loaded model — is untouched by moving.
//
// A page without the frame — a redirect stub above all — is
// navigated to in full, as is a page that cannot be fetched
// or read: the swap is an enhancement of plain navigation,
// never a prerequisite for it.

import { navigate } from "./navigate";

export default function LinkInterceptor() {
  useEffect(() => {
    const onClick = (event: MouseEvent) => {
      if (event.defaultPrevented) return;
      if (event.button !== 0) return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
        return;
      }
      const target = event.target;
      if (!(target instanceof Element)) return;
      const anchor = target.closest("a");
      if (!anchor) return;
      if (anchor.target && anchor.target !== "_self") return;
      if (anchor.hasAttribute("download")) return;
      const href = anchor.getAttribute("href");
      if (!href) return;
      // Internal links are written root-relative; an absolute
      // URL for this same origin is internal too.
      let url: URL;
      try {
        url = new URL(href, window.location.href);
      } catch {
        return;
      }
      if (url.origin !== window.location.origin) return;
      if (url.pathname.startsWith("/assets/")) return;
      // An anchor on the page being read: let the browser
      // scroll, as it always has.
      if (
        url.pathname === window.location.pathname &&
        url.search === window.location.search
      ) {
        return;
      }
      event.preventDefault();
      void navigate(url, false);
    };
    const onPopState = () => {
      void navigate(new URL(window.location.href), true);
    };
    document.addEventListener("click", onClick);
    window.addEventListener("popstate", onPopState);
    return () => {
      document.removeEventListener("click", onClick);
      window.removeEventListener("popstate", onPopState);
    };
  }, []);

  return null;
}
