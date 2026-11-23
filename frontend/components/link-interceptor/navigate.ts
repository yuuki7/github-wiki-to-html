import { swapPage } from "./swap";

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
