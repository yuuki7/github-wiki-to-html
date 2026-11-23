"use client";

import { useEffect } from "react";

// The copy buttons on code blocks. The build gives every code
// block a button carrying its code (see lib/markdown.ts); this
// listener, mounted once by the page shell, is the button's
// behaviour: copy the code, and show the word for it in the
// pill beside the button — the button's live region — for a
// moment.

export default function CodeCopy() {
  useEffect(() => {
    const onClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const button = target.closest(".expressive-code .copy button");
      if (!(button instanceof HTMLButtonElement)) return;
      const live = button.parentElement?.querySelector("[aria-live]");
      void navigator.clipboard
        ?.writeText(button.dataset.code ?? "")
        .then(() => {
          if (live) {
            live.textContent = button.dataset.copied ?? "";
            live.classList.add("show");
          }
          window.setTimeout(() => {
            if (live) {
              live.textContent = "";
              live.classList.remove("show");
            }
          }, 2000);
        })
        .catch(() => {
          // No clipboard: the button simply does nothing.
        });
    };
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, []);

  return null;
}
