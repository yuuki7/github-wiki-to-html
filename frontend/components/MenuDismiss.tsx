"use client";

import { useEffect } from "react";
import { mostRecentLayer } from "../lib/layers";

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
// open — so the listener leaves the bar alone. A tap on
// the AI assistant is likewise its own business, buttons
// and all: the window floats over the page beside the
// panel, and touching it is not turning back to the
// article, so it neither closes the menu nor is swallowed
// by the closing. When both layers stand, a tap back on
// the article puts away the one opened most recently
// (see lib/layers.ts): if that is the window, this tap
// is the window's dismissal, not the menu's, and the
// listener leaves it alone — the window's own dismissal
// acts on the press's release, before this click, so
// whether the window stood when the click arrives is
// not the test; the listener notes whether it stood
// when the press began. One outside tap is not
// swallowed: the header's language button. It opens a
// menu of its own, and menus take each other's place —
// the tap closes this menu and goes on to the button,
// so the language menu opens at once, not on a second
// tap. On a wide
// screen the menu is a plain sidebar, never open, and the
// listener does nothing.

export default function MenuDismiss() {
  useEffect(() => {
    const menu = () =>
      document.querySelector<HTMLDetailsElement>(".left-sidebar > details");
    let aiStoodAtPress = false;
    const onPointerDown = () => {
      aiStoodAtPress = !!document.querySelector(".ai-assistant__window");
    };
    const onClick = (event: MouseEvent) => {
      const details = menu();
      if (!details?.open) return;
      const target = event.target;
      if (!(target instanceof Element)) return;
      if (target.closest(".bottom-bar")) return;
      if (target.closest(".ai-assistant")) return;
      if (!details.contains(target)) {
        if (target.closest(".language-menu__button")) {
          details.open = false;
          return;
        }
        if (aiStoodAtPress && mostRecentLayer() === "ai") return;
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
    document.addEventListener("pointerdown", onPointerDown, true);
    document.addEventListener("click", onClick, true);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown, true);
      document.removeEventListener("click", onClick, true);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, []);

  return null;
}
