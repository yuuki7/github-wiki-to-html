"use client";

import { useEffect, useRef, useState } from "react";
import { noteLayerOpened } from "../lib/layers";

// The bar's fade, in the scroll's own terms. Fading is
// proportional: the distance below takes the bar from
// opaque to its most translucent, a quarter. Coming back
// asks more of the reader first: the upward distance
// below must be scrolled before the bar starts back at
// all — a reader's small upward checks while reading do
// not bring it back — and past that distance it returns
// at the same proportion.
const FADE_DISTANCE = 200;
const RESTORE_THRESHOLD = 100;
const MIN_OPACITY = 0.25;
const FADE_RATE = (1 - MIN_OPACITY) / FADE_DISTANCE;

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
// The bar's opacity follows the reader's scrolling, in
// the manner of the bars readers already know from the
// large platforms: scrolling down fades it gradually, in
// proportion to the distance scrolled, down to a quarter
// opaque, so the article shows through it and the bar
// costs the reading less of the screen; scrolling up
// brings it back only after a certain amount of upward
// scrolling, and then at the same proportion; at the top
// of the page it is always opaque. It follows the scroll
// position's movement — the one signal every way of
// scrolling gives, scrollbar drags included — with care
// for the movements that are not the reader scrolling: a
// page still arriving settles only the bar's starting
// point, a navigation by the frame starts it opaque
// again, and a leap of more than a screenful is a jump
// to somewhere, not a scroll.
//
// On the home page itself, the home button goes nowhere
// and shows its house filled in: the reader is already
// there, a link to the page being read would only load
// it again, and the filled house is the mark of the
// current place, as on the platforms readers know. Going
// nowhere is not doing nothing, though: its work there
// is to show the home article itself, so it puts away
// what stands over it — the menu, and the AI window,
// which it asks to minimize with an event, as the bar's
// AI button asks it to toggle. From any other page the
// button is a plain link home, and the window rides the
// navigation as it always does. In
// both its forms the house's doorway is open at the
// bottom: the bottom line runs under the walls only and
// stops at the doorway's sides, in the outline as two
// strokes that end there, in the filled house as a notch
// cut up from the bottom edge. In-app
// navigation keeps the button's state current as it does
// its destination (see the swap and the frame:navigated
// event).
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
  homeCurrent: boolean;
};

export default function BottomBar({
  homeHref,
  homeLabel,
  contentsLabel,
  homeCurrent,
}: Props) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [atHome, setAtHome] = useState(homeCurrent);
  const barRef = useRef<HTMLElement>(null);
  const homeRef = useRef<HTMLAnchorElement>(null);

  // Whether the page being read is the home page, kept
  // current across in-app navigation: the frame sets the
  // bar's home destination for the new page (see the
  // swap), and its navigated event says the move is done.
  useEffect(() => {
    const update = () => {
      const href = homeRef.current?.getAttribute("href");
      setAtHome(!!href && href === window.location.pathname);
    };
    update();
    window.addEventListener("frame:navigated", update);
    return () => window.removeEventListener("frame:navigated", update);
  }, []);

  useEffect(() => {
    const onToggle = (event: Event) => {
      const details = event.target;
      if (
        details instanceof HTMLDetailsElement &&
        details.closest(".left-sidebar")
      ) {
        setMenuOpen(details.open);
        if (details.open) noteLayerOpened("menu");
      }
    };
    document.addEventListener("toggle", onToggle, true);
    return () => document.removeEventListener("toggle", onToggle, true);
  }, []);

  // The bar's opacity, driven by the scroll position's
  // movement and written straight to the bar's style: it
  // changes with every step of a scroll, and rendering
  // each step through React would trail behind the
  // reader's finger. Every way of scrolling moves the
  // position — a finger's drag, a wheel, the keys, and a
  // scrollbar drag, which gives no other signal — so the
  // position is the thing to follow.
  //
  // Downward, each step takes the bar's opacity down in
  // proportion to its length. Upward, steps first add up
  // against the restore threshold — any downward step
  // clears the sum — and only the distance past it counts,
  // bringing the opacity back at the same proportion. At
  // the top of the page the bar is opaque outright.
  //
  // Three movements of the position are not the reader
  // scrolling, and the bar takes no direction from them:
  //
  // - A page still arriving. A reload partway down a
  //   page restores its position while the page loads,
  //   and until the position has been quiet a while,
  //   movements only settle where the bar starts from.
  //   The bar therefore starts opaque however far down
  //   the page loads.
  // - A navigation by the frame, which sets the position
  //   itself and says so (frame:navigated, see the
  //   link interceptor): the bar starts opaque again, as
  //   at a load, from the position the frame set.
  // - A leap: one movement of more than a screenful is a
  //   jump to somewhere — the bar takes the new position
  //   as its starting point and keeps its opacity.
  //
  // A press on the bar itself restores it outright,
  // whatever its faded state: a reader reaching for one
  // of its buttons gets the bar solid under the finger,
  // and the fading starts again from there. The Contents
  // button is the one exception: its press is not the
  // restore, its opening of the menu is. The menu's
  // toggle event reaches this effect after the open
  // state has been painted — the button's icon already
  // the close mark, the panel already standing — and
  // only then does the bar turn opaque, so the reader
  // never sees a solid bar still wearing the menu icon,
  // nor a faded close mark waiting on the bar.
  useEffect(() => {
    const bar = barRef.current;
    if (!bar) return;
    let opacity = 1;
    let upTravel = 0;
    let previous = window.scrollY;
    let armed = false;
    let timer: number | undefined;
    const apply = () => {
      bar.style.opacity = String(opacity);
    };
    const settle = () => {
      window.clearTimeout(timer);
      timer = window.setTimeout(() => {
        armed = true;
        previous = window.scrollY;
      }, 250);
    };
    const onScroll = () => {
      const y = window.scrollY;
      if (!armed) {
        previous = y;
        settle();
        return;
      }
      if (
        document.querySelector<HTMLDetailsElement>(".left-sidebar > details")
          ?.open
      ) {
        // While the menu stands, the fading is off
        // entirely: the reader is working with the menu
        // and the bar that controls it, and the article's
        // scrolling behind the panel is not a signal to
        // fade the bar. The position still tracks, so the
        // fading resumes from here when the menu closes.
        previous = y;
        return;
      }
      const step = y - previous;
      previous = y;
      if (Math.abs(step) > window.innerHeight * 1.5) {
        upTravel = 0;
        return;
      }
      if (y <= 0) {
        opacity = 1;
        upTravel = 0;
      } else if (step > 0) {
        upTravel = 0;
        opacity = Math.max(MIN_OPACITY, opacity - step * FADE_RATE);
      } else if (step < 0) {
        const before = upTravel;
        upTravel += -step;
        const applied =
          Math.max(0, upTravel - RESTORE_THRESHOLD) -
          Math.max(0, before - RESTORE_THRESHOLD);
        if (applied > 0) {
          opacity = Math.min(1, opacity + applied * FADE_RATE);
        }
      }
      apply();
    };
    const onNavigated = () => {
      opacity = 1;
      upTravel = 0;
      armed = false;
      previous = window.scrollY;
      apply();
      settle();
    };
    const onPress = (event: PointerEvent) => {
      if (
        event.target instanceof Element &&
        event.target.closest(".bottom-bar__button--contents")
      ) {
        return;
      }
      opacity = 1;
      upTravel = 0;
      apply();
    };
    const onMenuToggle = (event: Event) => {
      const details = event.target;
      if (
        details instanceof HTMLDetailsElement &&
        details.closest(".left-sidebar") &&
        details.open
      ) {
        opacity = 1;
        upTravel = 0;
        apply();
      }
    };
    settle();
    bar.addEventListener("pointerdown", onPress);
    document.addEventListener("toggle", onMenuToggle, true);
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("frame:navigated", onNavigated);
    return () => {
      window.clearTimeout(timer);
      bar.removeEventListener("pointerdown", onPress);
      document.removeEventListener("toggle", onMenuToggle, true);
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("frame:navigated", onNavigated);
    };
  }, []);

  // On the home page the home button is a no-op: the
  // link points at the page being read, and following it
  // would only load the page again. Preventing the click
  // also keeps the link interceptor from acting — it
  // leaves an already-prevented click alone.
  const onHomeClick = (event: React.MouseEvent<HTMLAnchorElement>) => {
    const href = event.currentTarget.getAttribute("href");
    if (href && href === window.location.pathname) {
      event.preventDefault();
      const details = document.querySelector<HTMLDetailsElement>(
        ".left-sidebar > details",
      );
      if (details) details.open = false;
      window.dispatchEvent(new Event("ai-assistant:minimize"));
    }
  };

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
    <nav ref={barRef} className="bottom-bar">
      <a
        ref={homeRef}
        className="bottom-bar__button"
        href={homeHref}
        aria-label={homeLabel}
        aria-current={atHome ? "page" : undefined}
        onClick={onHomeClick}
      >
        {atHome ? (
          <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2h-4v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8H5a2 2 0 0 1-2-2z" />
          </svg>
        ) : (
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
            <path d="M9 21H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2h-4" />
          </svg>
        )}
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
