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

// The head elements that are one page's own: its title, its
// canonical and alternate URLs, its author and social
// metadata, and its structured data. The rest of the head —
// the charset and viewport, the icon, the stylesheet — is
// every page's alike and stays.
const pageHeadSelector =
  "title, link[rel='canonical'], link[rel='alternate'], " +
  "meta[name='author'], meta[property^='og:'], " +
  "meta[property^='article:'], meta[name^='twitter:'], " +
  "script[type='application/ld+json']";

// One navigation in flight at a time: a newer one supersedes
// an older fetch still outstanding.
let navigationSerial = 0;

// The scroll position of the page being left, kept in its
// history entry so going back returns to it. The entry's
// other state — the framework's own keys — is preserved.
function rememberScroll(): void {
  try {
    history.replaceState(
      { ...(history.state ?? {}), frameScroll: window.scrollY },
      "",
    );
  } catch {
    // History state is an enhancement; navigation goes on.
  }
}

// The head: drop this page's own elements and take the new
// page's, in the new head's own order.
function swapHead(newDocument: Document): void {
  const newElements = newDocument.head.querySelectorAll(pageHeadSelector);
  document.head
    .querySelectorAll(pageHeadSelector)
    .forEach((element) => element.remove());
  newElements.forEach((element) =>
    document.head.appendChild(document.importNode(element, true)),
  );
}

// The header's navigation: the site-name link a home page
// omits, and the language switcher, whose links are this
// page's in the other languages. Both are updated in place —
// an element whose destination or wording changed keeps its
// identity; only an element that genuinely appears or
// disappears is inserted or removed.
function swapHeader(newDocument: Document): void {
  const nav = document.querySelector(".header nav");
  const newNav = newDocument.querySelector(".header nav");
  if (!nav || !newNav) return;

  const homeLink = (root: Element): HTMLAnchorElement | null =>
    [...root.children].find(
      (child): child is HTMLAnchorElement => child.tagName === "A",
    ) ?? null;
  const currentHome = homeLink(nav);
  const newHome = homeLink(newNav);
  if (currentHome && newHome) {
    const href = newHome.getAttribute("href");
    if (href) currentHome.setAttribute("href", href);
    currentHome.textContent = newHome.textContent;
  } else if (!currentHome && newHome) {
    nav.prepend(document.importNode(newHome, true));
  } else if (currentHome && !newHome) {
    currentHome.remove();
  }

  const menu = nav.querySelector(".language-menu");
  const newMenu = newNav.querySelector(".language-menu");
  if (menu && newMenu) {
    // The button names the current language.
    const button = menu.querySelector(".language-menu__button");
    const newButton = newMenu.querySelector(".language-menu__button");
    if (button && newButton) button.textContent = newButton.textContent;

    // The panel's items, one per language, matched by their
    // language names: a link stays a link and only its
    // destination is rewritten; the current language's item
    // is a span, and becoming or ceasing to be current is the
    // one change of kind.
    const panel = menu.querySelector(".language-menu__panel");
    const newPanel = newMenu.querySelector(".language-menu__panel");
    if (panel && newPanel) {
      const items = new Map(
        [...panel.children].map((item) => [item.textContent.trim(), item]),
      );
      for (const newItem of [...newPanel.children]) {
        const key = newItem.textContent.trim();
        const item = items.get(key);
        if (!item) {
          panel.appendChild(document.importNode(newItem, true));
          continue;
        }
        items.delete(key);
        const current = item.firstElementChild;
        const next = newItem.firstElementChild;
        if (current && next && current.tagName === next.tagName) {
          if (
            current instanceof HTMLAnchorElement &&
            next instanceof HTMLAnchorElement
          ) {
            const href = next.getAttribute("href");
            if (href) current.setAttribute("href", href);
            const hrefLang = next.getAttribute("hrefLang");
            if (hrefLang) current.setAttribute("hrefLang", hrefLang);
            const lang = next.getAttribute("lang");
            if (lang) current.setAttribute("lang", lang);
          }
        } else if (next) {
          item.replaceChildren(document.importNode(next, true));
        }
      }
      items.forEach((item) => item.remove());
    }
  } else if (!menu && newMenu) {
    nav.appendChild(document.importNode(newMenu, true));
  } else if (menu && !newMenu) {
    menu.remove();
  }
}

// The footer: its fragment is one language's, the same on
// every page in it, and only its last element — the edit
// link — is the page's own. The fragment is replaced only
// when it actually differs, and the edit link is updated in
// place.
function swapFooter(newDocument: Document): void {
  const footer = document.querySelector(".footer");
  const newFooter = newDocument.querySelector(".footer");
  if (!footer || !newFooter) return;

  const editLink = (root: Element): HTMLAnchorElement | null => {
    const last = root.lastElementChild;
    return last instanceof HTMLAnchorElement ? last : null;
  };
  const fragmentHtml = (root: Element, link: HTMLAnchorElement | null) =>
    [...root.childNodes]
      .filter((node) => node !== link)
      .map((node) =>
        node instanceof Element ? node.outerHTML : (node.textContent ?? ""),
      )
      .join("");
  const currentLink = editLink(footer);
  const newLink = editLink(newFooter);
  if (fragmentHtml(footer, currentLink) !== fragmentHtml(newFooter, newLink)) {
    footer.replaceChildren(
      ...[...newFooter.childNodes]
        .filter((node) => node !== newLink)
        .map((node) => document.importNode(node, true)),
    );
    if (currentLink) footer.appendChild(currentLink);
  }
  if (currentLink && newLink) {
    const href = newLink.getAttribute("href");
    if (href) currentLink.setAttribute("href", href);
    currentLink.textContent = newLink.textContent;
  } else if (!currentLink && newLink) {
    footer.appendChild(document.importNode(newLink, true));
  } else if (currentLink && !newLink) {
    currentLink.remove();
  }
}

// The right sidebar: the AI assistant itself is never
// touched — its state is the reader's — but its texts are
// the page's language's, so they are updated in place: the
// section's data attributes, which the box reads its texts
// from when it acts, the input's placeholder, and the send
// button's label.
function swapRightAside(newDocument: Document): void {
  const section = document.querySelector(".ai-assistant");
  const newSection = newDocument.querySelector(".ai-assistant");
  if (!section || !newSection) return;
  for (const name of ["summarize", "loading", "send", "unsupported", "error"]) {
    const value = newSection.getAttribute(`data-${name}`);
    if (value !== null) section.setAttribute(`data-${name}`, value);
  }
  // The fetched document's box is its unmounted form — a
  // heading only — so the visible labels are taken from the
  // data attributes: the placeholder is the summarize text,
  // and the button's label is the send text.
  const input = section.querySelector(".ai-assistant__input");
  const placeholder = newSection.getAttribute("data-summarize");
  if (input && placeholder !== null) {
    input.setAttribute("placeholder", placeholder);
  }
  const send = section.querySelector(".ai-assistant__send");
  const sendText = newSection.getAttribute("data-send");
  if (send && sendText !== null) send.textContent = sendText;
}

// Replace the page's own regions with the new document's,
// leaving the rest of the document — the frame — untouched.
function swapPage(newDocument: Document): void {
  const newRoot = newDocument.querySelector(".page-root");
  if (!newRoot) return;

  const html = document.documentElement;
  const newHtml = newDocument.documentElement;
  html.setAttribute("lang", newHtml.getAttribute("lang") ?? "en");
  const dir = newHtml.getAttribute("dir");
  if (dir) html.setAttribute("dir", dir);

  swapHead(newDocument);

  const root = document.querySelector(".page-root");
  if (root) root.className = newRoot.className;

  swapHeader(newDocument);

  const left = document.querySelector(".left-sidebar");
  const newLeft = newDocument.querySelector(".left-sidebar");
  if (left && newLeft) left.innerHTML = newLeft.innerHTML;

  const main = document.querySelector(".main");
  const newMain = newDocument.querySelector(".main");
  if (main && newMain) main.innerHTML = newMain.innerHTML;

  swapRightAside(newDocument);
  swapFooter(newDocument);
}

// The mathematics in the new article, typeset as it would
// have been had the page loaded in full. MathJax may not
// have loaded, or may have failed to: the article reads
// without it, as an untypeset page does.
async function typesetArticle(): Promise<void> {
  try {
    const mathJax = (
      window as unknown as {
        MathJax?: { typesetPromise?: (elements: Element[]) => Promise<void> };
      }
    ).MathJax;
    const main = document.querySelector(".main");
    if (mathJax?.typesetPromise && main) {
      await mathJax.typesetPromise([main]);
    }
  } catch {
    // Typesetting is left undone.
  }
}

// Go to one internal URL by swapping the page's regions. A
// document that cannot be fetched, or that carries no frame
// — a redirect stub, an error page — is gone to in full
// instead. With `pop`, the move answers a history traversal
// and pushes no entry of its own.
async function navigate(url: URL, pop: boolean): Promise<void> {
  const serial = ++navigationSerial;
  let newDocument: Document | null = null;
  try {
    const response = await fetch(url.href, { credentials: "same-origin" });
    if (!response.ok) throw new Error(response.statusText);
    const text = await response.text();
    newDocument = new DOMParser().parseFromString(text, "text/html");
  } catch {
    newDocument = null;
  }
  if (serial !== navigationSerial) return;
  if (
    !newDocument ||
    !newDocument.querySelector(".page-root") ||
    newDocument.querySelector("meta[http-equiv='refresh']")
  ) {
    window.location.assign(url.href);
    return;
  }

  if (!pop) {
    rememberScroll();
    history.pushState({ frameNav: true }, "", url.href);
  }
  swapPage(newDocument);

  const target = url.hash
    ? document.getElementById(decodeURIComponent(url.hash.slice(1)))
    : null;
  if (target) {
    target.scrollIntoView();
  } else if (pop) {
    const state = history.state as { frameScroll?: number } | null;
    window.scrollTo(0, state?.frameScroll ?? 0);
  } else {
    window.scrollTo(0, 0);
  }

  void typesetArticle();
}

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
