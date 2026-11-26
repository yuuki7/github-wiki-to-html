"use client";

import { useEffect } from "react";

// Closing the narrow screen's menu from outside it. The
// menu is a <details> in the left sidebar (see Shell), and
// the bottom bar's Contents button is its control: a
// details has no way of its own to close when the reader
// taps the page beside its panel, as a reader expects a
// drawer to close. This listener, mounted once by the
// page shell, is that close. A tap outside the menu closes
// it and goes no further; a tap on a link inside the panel
// closes it and follows the link, so the reader lands on
// what the link points at, not on the open panel; Escape
// closes it. A tap on the bottom bar is the bar's own
// business — its Contents button toggles the menu itself,
// and its other buttons must still work while the menu is
// open — so the listener leaves the bar alone. On a wide
// screen the menu is a plain sidebar, never open, and the
// listener does nothing.

export default function MenuDismiss() {
  useEffect(() => {
    const menu = () =>
      document.querySelector<HTMLDetailsElement>(".left-sidebar > details");
    const onClick = (event: MouseEvent) => {
      const details = menu();
      if (!details?.open) return;
      const target = event.target;
      if (!(target instanceof Element)) return;
      if (target.closest(".bottom-bar")) return;
      if (!details.contains(target)) {
        event.preventDefault();
        event.stopPropagation();
        details.open = false;
        return;
      }
      if (target.closest("a")) details.open = false;
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      const details = menu();
      if (details?.open) details.open = false;
    };
    document.addEventListener("click", onClick, true);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("click", onClick, true);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, []);

  return null;
}
