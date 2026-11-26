"use client";

import { useEffect, useState } from "react";

// The narrow screen's bottom bar: one bar across the
// page's foot, holding the controls that float as separate
// buttons on a wide screen — back to the home page at the
// left, the menu in the middle, the AI assistant at the
// right. The stylesheet shows it only on a narrow screen;
// on a wide one the menu's sidebar and the assistant's
// launcher keep their own places, and the bar is not
// shown at all. Its buttons are icons only: their names
// are spoken, not shown, and in-app navigation keeps the
// names and the home button's destination in the page's
// language, as it does the header's (see the swap).
//
// The bar stands opaque when the page loads and whenever
// the reader scrolls up; scrolling down makes it
// translucent, so the article shows through it and the
// bar costs the reading less of the screen.
//
// The bar's buttons reach the things they control where
// those things live. The home button is a plain link, and
// in-app navigation carries it like any other. The
// Contents button opens and closes the left sidebar's
// <details> — the menu itself — and reports its state; the
// menu has other closes besides (a tap beside its panel,
// Escape, a link inside it), so the button takes its state
// from the details' own toggle event, not from its
// clicks. The AI button asks the assistant to toggle
// itself, with an event the assistant listens for: the
// assistant owns its window's state, and the bar does not
// reach into it.

type Props = {
  homeHref: string;
  homeLabel: string;
  contentsLabel: string;
};

export default function BottomBar({
  homeHref,
  homeLabel,
  contentsLabel,
}: Props) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [translucent, setTranslucent] = useState(false);

  useEffect(() => {
    const onToggle = (event: Event) => {
      const details = event.target;
      if (
        details instanceof HTMLDetailsElement &&
        details.closest(".left-sidebar")
      ) {
        setMenuOpen(details.open);
      }
    };
    document.addEventListener("toggle", onToggle, true);
    return () => document.removeEventListener("toggle", onToggle, true);
  }, []);

  // The bar's translucency follows the reader's own
  // scrolling — the wheel's turn, the finger's drag, the
  // scrolling keys — and nothing else. It does not follow
  // the scroll position: a change of position is not
  // necessarily the reader scrolling. A reload partway
  // down a page restores the position on its own, and a
  // jump to a heading moves it at a stroke; neither may
  // fade the bar. The bar starts opaque however far down
  // the page loads, and only the reader's scrolling fades
  // it: down fades it, up — a reader going back for
  // something — brings it back solid. Small movements
  // settle nothing, so a direction counts only past a
  // few pixels.
  useEffect(() => {
    let lastTouchY: number | null = null;
    const onWheel = (event: WheelEvent) => {
      if (event.deltaY > 4) setTranslucent(true);
      else if (event.deltaY < -4) setTranslucent(false);
    };
    const onTouchStart = (event: TouchEvent) => {
      lastTouchY = event.touches[0]?.clientY ?? null;
    };
    const onTouchMove = (event: TouchEvent) => {
      const y = event.touches[0]?.clientY;
      if (y === undefined || lastTouchY === null) return;
      if (lastTouchY - y > 4) {
        setTranslucent(true);
        lastTouchY = y;
      } else if (y - lastTouchY > 4) {
        setTranslucent(false);
        lastTouchY = y;
      }
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (["ArrowDown", "PageDown", " ", "End"].includes(event.key)) {
        setTranslucent(true);
      } else if (["ArrowUp", "PageUp", "Home"].includes(event.key)) {
        setTranslucent(false);
      }
    };
    window.addEventListener("wheel", onWheel, { passive: true });
    window.addEventListener("touchstart", onTouchStart, { passive: true });
    window.addEventListener("touchmove", onTouchMove, { passive: true });
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("wheel", onWheel);
      window.removeEventListener("touchstart", onTouchStart);
      window.removeEventListener("touchmove", onTouchMove);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, []);

  const toggleMenu = () => {
    const details = document.querySelector<HTMLDetailsElement>(
      ".left-sidebar > details",
    );
    if (details) details.open = !details.open;
  };

  const toggleAssistant = () => {
    window.dispatchEvent(new Event("ai-assistant:toggle"));
  };

  return (
    <nav
      className={
        translucent ? "bottom-bar bottom-bar--translucent" : "bottom-bar"
      }
    >
      <a className="bottom-bar__button" href={homeHref} aria-label={homeLabel}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8" />
          <path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
        </svg>
      </a>
      <button
        type="button"
        className="bottom-bar__button bottom-bar__button--contents"
        aria-label={contentsLabel}
        aria-expanded={menuOpen}
        onClick={toggleMenu}
      >
        <svg
          className="bottom-bar__icon bottom-bar__icon--menu"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <path d="M4 7h16M4 12h10M4 17h13" />
        </svg>
        <svg
          className="bottom-bar__icon bottom-bar__icon--close"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.75"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <path d="M18 6 6 18M6 6l12 12" />
        </svg>
      </button>
      <button
        type="button"
        className="bottom-bar__button bottom-bar__button--ai"
        aria-label="AI"
        onClick={toggleAssistant}
      >
        <span className="bottom-bar__bear" aria-hidden="true">
          🧸
        </span>
      </button>
    </nav>
  );
}
