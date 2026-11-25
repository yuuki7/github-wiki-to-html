import { swapPage } from "./swap";

// One navigation in flight at a time: a newer one supersedes
// an older fetch still outstanding.
let navigationSerial = 0;

function decodeHash(hash: string): string {
  try {
    return decodeURIComponent(hash);
  } catch {
    return hash;
  }
}

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

// The mathematics in the article now in place, typeset by
// the shell: MathJax is configured not to typeset on its
// own, so a page reached by a full load is typeset from
// here too, once the framework has hydrated it — typesetting
// before that would race the hydration and be thrown away
// with the article it rewrote. MathJax may not have loaded,
// or may have failed to: the article reads without it, as an
// untypeset page does.
export async function typesetArticle(): Promise<void> {
  try {
    const readMathJax = () =>
      (
        window as unknown as {
          MathJax?: {
            startup?: { promise?: Promise<void> };
            typesetPromise?: (elements: Element[]) => Promise<void>;
          };
        }
      ).MathJax;
    // On a full load this call can come while MathJax is
    // still starting: its typesetting function is attached
    // only when the startup completes, which the startup
    // promise settles with. Wait for that first, then
    // typeset. On a later navigation the promise has long
    // settled, and waiting costs nothing.
    await readMathJax()?.startup?.promise;
    const mathJax = readMathJax();
    const main = document.querySelector(".main");
    if (mathJax?.typesetPromise && main) {
      await mathJax.typesetPromise([main]);
    }
  } catch {
    // Typesetting is left undone.
  }
}

// A code block wider than its frame scrolls sideways, and
// one that overflows is made focusable, as the site's wide
// tables are, so it can be scrolled from the keyboard too.
// Expressive Code ships a script that keeps this true, but
// a swapped-in page's scripts do not run — the same reason
// the mathematics above is typeset from here — so the shell
// keeps it true itself: when a page arrives, and when the
// window changes size.
export function enhanceCodeBlocks(): void {
  document.querySelectorAll(".expressive-code pre").forEach((pre) => {
    if (pre.scrollWidth > pre.clientWidth) {
      pre.setAttribute("tabindex", "0");
      pre.setAttribute("role", "region");
    } else {
      pre.removeAttribute("tabindex");
      pre.removeAttribute("role");
    }
  });
}

// Go to one internal URL by swapping the page's regions. A
// document that cannot be fetched, or that carries no frame
// — a redirect stub, an error page — is gone to in full
// instead. With `pop`, the move answers a history traversal
// and pushes no entry of its own.
export async function navigate(url: URL, pop: boolean): Promise<void> {
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
    ? document.getElementById(decodeHash(url.hash.slice(1)))
    : null;
  if (target) {
    target.scrollIntoView();
  } else if (pop) {
    const state = history.state as { frameScroll?: number } | null;
    window.scrollTo(0, state?.frameScroll ?? 0);
  } else {
    window.scrollTo(0, 0);
  }

  enhanceCodeBlocks();
  void typesetArticle();
}
