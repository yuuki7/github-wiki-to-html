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
    setText(currentHome, newHome.textContent);
  } else if (!currentHome && newHome) {
    nav.prepend(document.importNode(newHome, true));
  } else if (currentHome && !newHome) {
    currentHome.remove();
  }

  const menu = nav.querySelector(".language-menu");
  const newMenu = newNav.querySelector(".language-menu");
  if (menu && newMenu) {
    // The button names the current language, in the text
    // node after its globe: update that node in place, and
    // only when the name changed.
    const button = menu.querySelector(".language-menu__button");
    const newButton = newMenu.querySelector(".language-menu__button");
    if (button && newButton && button.textContent !== newButton.textContent) {
      const textNode = (root: Element): Text | null =>
        [...root.childNodes].find(
          (node): node is Text =>
            node instanceof Text && node.textContent.trim() !== "",
        ) ?? null;
      const current = textNode(button);
      const next = textNode(newButton);
      if (current && next) current.nodeValue = next.textContent;
    }

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
    setText(currentLink, newLink.textContent);
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
  if (send && sendText !== null) setText(send, sendText);
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

  const left = document.querySelector(".left-sidebar");
  const newLeft = newDocument.querySelector(".left-sidebar");
  if (left && newLeft) left.innerHTML = newLeft.innerHTML;

  const main = document.querySelector(".main");
  const newMain = newDocument.querySelector(".main");
  if (main && newMain) main.innerHTML = newMain.innerHTML;

  swapRightAside(newDocument);
  swapFooter(newDocument);
}
