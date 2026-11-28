import type { LanguageMenuData, SidebarMenuData } from "../../lib/types";

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

// Set an element's text only when the text actually
// changes, and change it in its existing text node where it
// has one: assigning textContent replaces the node even
// when the new text is the same as the old, and a selection
// the reader has in that text dies with the node.
function setText(element: Element, text: string): void {
  if (element.textContent === text) return;
  const only = element.childNodes.length === 1 ? element.firstChild : null;
  if (only instanceof Text) {
    only.nodeValue = text;
  } else {
    element.textContent = text;
  }
}

function copyAttributes(
  target: Element,
  source: Element,
  names: readonly string[],
): void {
  for (const name of names) {
    const value = source.getAttribute(name);
    if (value !== null) target.setAttribute(name, value);
  }
}

function replaceChildrenFrom(target: Element, source: Element): void {
  target.replaceChildren(
    ...[...source.childNodes].map((node) => document.importNode(node, true)),
  );
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
// page's in the other languages. The link is updated in
// place — an element whose destination or wording changed
// keeps its identity; only an element that genuinely
// appears or disappears is inserted or removed. The
// switcher is handed its page's languages as data, below.
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
    setText(currentHome, newHome.textContent);
  } else if (!currentHome && newHome) {
    nav.prepend(document.importNode(newHome, true));
  } else if (currentHome && !newHome) {
    currentHome.remove();
  }

  // The language menu is the frame's own component (see
  // LanguageMenu), and its panel is the component's to
  // render: the swap cannot rewrite it in place as it did
  // the plain list the component replaced. Instead the
  // swap reads the new page's languages from the document
  // itself — the page's language from its root element,
  // and one item per language from its hreflang links,
  // whose hrefs the head carries as absolute URLs, taken
  // back to paths here — and hands them over as data.
  // The current language's item carries no href: in the
  // menu it is not a link. The head also carries an
  // x-default link, for search engines; it is not a
  // language and never a menu item.
  const pageLanguage = newDocument.documentElement.lang || "en";
  const menuLinks: LanguageMenuData["links"] = [];
  newDocument
    .querySelectorAll("link[rel='alternate'][hreflang]")
    .forEach((link) => {
      const linkLanguage = link.getAttribute("hreflang");
      const href = link.getAttribute("href");
      if (!linkLanguage || !href || linkLanguage === "x-default") return;
      menuLinks.push({
        language: linkLanguage,
        href: linkLanguage === pageLanguage ? null : new URL(href).pathname,
      });
    });
  if (menuLinks.length > 0) {
    window.dispatchEvent(
      new CustomEvent<LanguageMenuData>("frame:language-menu", {
        detail: { language: pageLanguage, links: menuLinks },
      }),
    );
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
    setText(currentLink, newLink.textContent);
  } else if (!currentLink && newLink) {
    footer.appendChild(document.importNode(newLink, true));
  } else if (currentLink && !newLink) {
    currentLink.remove();
  }
}

// The bottom bar: its buttons are icons, the same in
// every language, but the home button's destination is
// the page's language's home page, and the buttons'
// accessible names are its words. They are updated in
// place, like the header's own link and names.
function swapBottomBar(newDocument: Document): void {
  const bar = document.querySelector(".bottom-bar");
  const newBar = newDocument.querySelector(".bottom-bar");
  if (!bar || !newBar) return;
  const current = [...bar.children];
  const next = [...newBar.children];
  for (let i = 0; i < Math.min(current.length, next.length); i++) {
    const target = current[i];
    const source = next[i];
    if (target && source) {
      copyAttributes(target, source, ["href", "aria-label"]);
    }
  }
}

// The right sidebar: the AI assistant itself is never
// touched — its state is the reader's — but its texts are
// the page's language's, so they are updated in place: the
// section's data attributes, which the box reads its texts
// from when it acts, the input's placeholder, and the send
// button's accessible name. The button's face is an arrow,
// not a word, so the face itself needs no swap.
function swapRightAside(newDocument: Document): void {
  const section = document.querySelector(".ai-assistant");
  const newSection = newDocument.querySelector(".ai-assistant");
  if (!section || !newSection) return;
  for (const name of [
    "summarize",
    "loading",
    "send",
    "unsupported",
    "error",
    "message",
  ]) {
    const value = newSection.getAttribute(`data-${name}`);
    if (value !== null) section.setAttribute(`data-${name}`, value);
  }
  const input = section.querySelector(".ai-assistant__input");
  const placeholder = newSection.getAttribute("data-message");
  if (input && placeholder !== null) {
    input.setAttribute("placeholder", placeholder);
  }
  const send = section.querySelector(".ai-assistant__send");
  const sendText = newSection.getAttribute("data-send");
  if (send && sendText !== null) send.setAttribute("aria-label", sendText);
}

// Replace the page's own regions with the new document's,
// leaving the rest of the document — the frame — untouched.
export function swapPage(newDocument: Document): void {
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

  // The left sidebar is an <aside> on every page; the menu
  // inside it is present only on pages that have one: a
  // page without a table of contents has none. The aside's
  // children are replaced whole, so the new page's menu
  // arrives as the page itself has it.
  const left = document.querySelector(".left-sidebar");
  const newLeft = newDocument.querySelector(".left-sidebar");
  if (left && newLeft) replaceChildrenFrom(left, newLeft);

  // The menu as a drawer is the frame's own component (see
  // TocDrawer), and its panel is the component's to render:
  // the swap cannot rewrite it in place as it does the
  // sidebar's plain list. Instead the swap reads the new
  // page's menu from the document itself — the menu's names
  // from the sidebar's data attributes, and one item per
  // entry of its list, a table of contents entry carrying
  // its heading's depth out of its class — and hands it
  // over as data. A page with no menu hands over no items,
  // and the drawer stands down. A menu the reader opened
  // belongs to the page they are leaving; the drawer closes
  // on the navigation, as a fresh load would leave it.
  if (newLeft) {
    const items: SidebarMenuData["items"] = [];
    newLeft.querySelectorAll("li").forEach((item) => {
      const link = item.querySelector("a");
      const href = link?.getAttribute("href");
      if (!link || !href) return;
      const depthToken = [...item.classList].find((token) =>
        token.startsWith("toc__item--depth-"),
      );
      const depth = depthToken
        ? Number(depthToken.slice("toc__item--depth-".length))
        : NaN;
      items.push({
        href,
        text: link.textContent.trim(),
        depth: Number.isFinite(depth) ? depth : undefined,
      });
    });
    window.dispatchEvent(
      new CustomEvent<SidebarMenuData>("frame:sidebar-menu", {
        detail: {
          kind: newLeft.querySelector("nav.toc") ? "toc" : "list",
          label: newLeft.getAttribute("data-contents-label") ?? "",
          closeLabel: newLeft.getAttribute("data-close-label") ?? "",
          items,
        },
      }),
    );
  }

  const main = document.querySelector(".main");
  const newMain = newDocument.querySelector(".main");
  if (main && newMain) replaceChildrenFrom(main, newMain);

  swapRightAside(newDocument);
  swapFooter(newDocument);
  swapBottomBar(newDocument);
}
