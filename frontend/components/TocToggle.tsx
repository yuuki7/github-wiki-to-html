"use client";

import { useEffect, useState } from "react";

// The menu's control while the AI panel stands on a wide
// screen: a button at the head of the article's title,
// wearing Lucide's table-of-contents. The menu itself —
// the left sidebar's <details> — leaves the page's layout
// while the panel stands, and opens as a drawer over the
// article; this button is its toggle there, as the bottom
// bar's Contents button is on a narrow screen, and the
// stylesheet shows it in that one state only. The button
// reports the menu's own state, taken from the details'
// toggle event, as the bottom bar's button does: the menu
// has other closes besides this one — a tap beside its
// panel, Escape, a link inside it. Its icon follows the
// menu's state in the stylesheet, as the bar's does: the
// table of contents while the menu is closed, a cross
// while it stands.

export default function TocToggle({ label }: { label: string }) {
  const [menuOpen, setMenuOpen] = useState(false);

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

  const toggleMenu = () => {
    const details = document.querySelector<HTMLDetailsElement>(
      ".left-sidebar > details",
    );
    if (details) details.open = !details.open;
  };

  return (
    <button
      type="button"
      className="toc-toggle"
      aria-label={label}
      aria-expanded={menuOpen}
      onClick={toggleMenu}
    >
      <svg
        className="toc-toggle__icon toc-toggle__icon--menu"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M16 5H3" />
        <path d="M16 12H3" />
        <path d="M16 19H3" />
        <path d="M21 5h.01" />
        <path d="M21 12h.01" />
        <path d="M21 19h.01" />
      </svg>
      <svg
        className="toc-toggle__icon toc-toggle__icon--close"
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
  );
}
