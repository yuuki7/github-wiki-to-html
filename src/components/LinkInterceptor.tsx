"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

// In-app navigation for the links inside rendered article
// bodies. The bodies are HTML the build produced, so their
// links are plain anchors; left alone, following one would
// reload the whole document and drop the app's state — the
// AI assistant's loaded model and conversation above all.
// This listener, mounted once by the page shell, hands
// internal links to the router instead. Links the reader
// plainly means to open elsewhere — a new tab, a file under
// the assets, an anchor on the same page — are left to the
// browser.

export default function LinkInterceptor() {
  const router = useRouter();

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
      if (!href || !href.startsWith("/") || href.startsWith("//")) return;
      if (href.startsWith("/assets/")) return;
      const url = new URL(href, window.location.href);
      // An anchor on the page being read: let the browser
      // scroll, as it always has.
      if (
        url.pathname === window.location.pathname &&
        url.search === window.location.search
      ) {
        return;
      }
      event.preventDefault();
      router.push(href);
    };
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [router]);

  return null;
}
