"use client";

import { useEffect, useState } from "react";
import { Drawer } from "@base-ui/react/drawer";
import type { SidebarMenuData } from "../lib/types";

// The left sidebar's menu as a drawer: the panel that stands
// over the page where the menu is not a plain sidebar — on a
// narrow screen, and on a wide one while the AI panel stands
// and the sidebar has left the layout. The content is the
// sidebar's own (see Shell): an article's table of contents,
// or a home page's list of articles.
//
// The panel is Base UI's Drawer, in its non-modal form: the
// page behind it stays the reader's — it scrolls, and a press
// on it puts the drawer away, as a press on the drawer itself
// works the drawer — while the library carries the layer's
// own dealings: the outside press and the Escape that close
// it, the swipe that drags it away, and the focus. What the
// hand-written menu before it carried in a <details> and a
// document listener of its own, the library carries now.
// One press is not an outside press: the bottom bar's. The
// bar is the drawer's own furniture — its Contents button
// toggles the drawer, and its other buttons do their own
// work while the drawer stands — so a dismissal the bar's
// press asks for is cancelled here, through the library's
// own veto, and the bar's events decide what happens.
// Focus leaving is not a dismissal either: the page behind
// the drawer stays the reader's to work with — the AI
// window above all, which focuses its own input as it
// opens — and the menu before this one had no close for
// it. The drawer's closes are the press, the Escape, the
// swipe, and its own controls.
//
// The drawer is the frame's own, like the language menu:
// rendered once, it stays while the reader moves between
// pages, and the swap cannot rewrite a component's panel in
// place. So the swap hands it each page's menu as data (the
// "frame:sidebar-menu" event, read from the new document's
// sidebar), and a navigation closes it, as a full load would
// leave it closed. Its controls stand elsewhere and ask by
// event, as the bar's AI button asks the assistant: the
// bottom bar's Contents button and the article title's own
// button (see TocToggle) ask it to toggle, and the home
// button's no-op and the assistant's dock ask it to close.
// It reports its state the same way (the "sidebar-menu:state"
// event and the body's menu-open class), for the bar's own
// button and fading, and it works the title button's
// expanded state onto whichever copy stands, as the frame
// writes its other state after a swap.

export default function TocDrawer({
  initialData,
}: {
  initialData: SidebarMenuData | null;
}) {
  const [data, setData] = useState<SidebarMenuData | null>(initialData);
  const [open, setOpen] = useState(false);
  const hasMenu = !!data && data.items.length > 0;

  useEffect(() => {
    const onMenuData = (event: Event) => {
      const detail = (event as CustomEvent<SidebarMenuData>).detail;
      if (detail) setData(detail);
    };
    const onNavigated = () => setOpen(false);
    const onToggle = () => {
      if (hasMenu) setOpen((value) => !value);
    };
    const onClose = () => setOpen(false);
    const onClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      if (target.closest(".toc-toggle")) onToggle();
    };
    window.addEventListener("frame:sidebar-menu", onMenuData);
    window.addEventListener("frame:navigated", onNavigated);
    window.addEventListener("sidebar-menu:toggle", onToggle);
    window.addEventListener("sidebar-menu:close", onClose);
    document.addEventListener("click", onClick);
    return () => {
      window.removeEventListener("frame:sidebar-menu", onMenuData);
      window.removeEventListener("frame:navigated", onNavigated);
      window.removeEventListener("sidebar-menu:toggle", onToggle);
      window.removeEventListener("sidebar-menu:close", onClose);
      document.removeEventListener("click", onClick);
    };
  }, [hasMenu]);

  // The state the rest of the frame reads: the bottom bar
  // reports it on its own button and holds its fading while
  // the menu stands, the stylesheet shows the controls'
  // open faces from the body's class, and the article
  // title's button — a fresh element on every page — takes
  // its expanded state from here.
  useEffect(() => {
    document.body.classList.toggle("menu-open", open);
    document
      .querySelector(".toc-toggle")
      ?.setAttribute("aria-expanded", String(open));
    window.dispatchEvent(
      new CustomEvent("sidebar-menu:state", { detail: { open } }),
    );
  }, [open]);

  if (!data || data.items.length === 0) return null;
  return (
    <Drawer.Root
      open={open}
      onOpenChange={(next, details) => {
        if (!next && details.reason === "focus-out") {
          details.cancel();
          return;
        }
        if (
          !next &&
          details.reason === "outside-press" &&
          details.event.target instanceof Element &&
          details.event.target.closest(".bottom-bar")
        ) {
          details.cancel();
          return;
        }
        setOpen(next);
      }}
      modal={false}
      swipeDirection="left"
    >
      <Drawer.Portal>
        <Drawer.Viewport className="sidebar-drawer__viewport">
          <Drawer.Popup
            className="sidebar-drawer__popup"
            onClick={(event) => {
              // A tap on a link inside the panel closes it
              // and follows the link, as a reader expects:
              // they land on what the link points at, not on
              // the open panel.
              if ((event.target as Element).closest("a")) setOpen(false);
            }}
          >
            <Drawer.Title className="sidebar-drawer__title">
              {data.label}
            </Drawer.Title>
            <div className="sidebar-drawer__bar">
              <Drawer.Close
                className="sidebar-drawer__close"
                aria-label={data.closeLabel}
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                  aria-hidden="true"
                >
                  <path d="M18 6 6 18M6 6l12 12" />
                </svg>
              </Drawer.Close>
            </div>
            <Drawer.Content className="sidebar-drawer__content">
              {data.kind === "toc" ? (
                <nav className="toc">
                  <ul>
                    {data.items.map((item) => (
                      <li
                        key={item.href}
                        className={`toc__item toc__item--depth-${item.depth ?? 2}`}
                      >
                        <a className="toc__link" href={item.href}>
                          {item.text}
                        </a>
                      </li>
                    ))}
                  </ul>
                </nav>
              ) : (
                <ul>
                  {data.items.map((item) => (
                    <li key={item.href}>
                      <a href={item.href}>{item.text}</a>
                    </li>
                  ))}
                </ul>
              )}
            </Drawer.Content>
          </Drawer.Popup>
        </Drawer.Viewport>
      </Drawer.Portal>
    </Drawer.Root>
  );
}
