"use client";

import { useEffect, useState } from "react";
import { Popover } from "@base-ui/react/popover";
import { languageName } from "../lib/i18n";
import type { AlternateLink, LanguageMenuData } from "../lib/types";

// The header's language switcher: a button naming the current
// language, opening a panel with every language. However many
// languages the site gains, the header keeps this one control.
//
// The panel is Base UI's Popover. Its positioner uses the
// library's absolute position method, so the panel sits in the
// page and travels with the button as the page scrolls — the
// form the reader settled when the panel was a native popover
// placed by anchor positioning.
//
// The menu is the frame's own: rendered once, it stays while
// the reader moves between pages, and the swap cannot rewrite
// a component's panel in place as it rewrote the plain list
// this replaces. So on an in-app navigation the swap hands
// the menu the new page's languages as data (the
// "frame:language-menu" event, read from the new document's
// hreflang links), and a navigation closes the menu, as a
// full load would leave it closed. On a home page the panel
// opens from the button's start edge, elsewhere from its end
// edge, as the plain list did.
export default function LanguageMenu({
  language,
  languageLinks,
  isHome,
}: {
  language: string;
  languageLinks: AlternateLink[];
  isHome: boolean;
}) {
  const [data, setData] = useState<LanguageMenuData>(() => ({
    language,
    links: languageLinks.map((link) => ({
      language: link.language,
      href: link.language === language ? null : link.href,
    })),
  }));
  const [open, setOpen] = useState(false);
  const [atHome, setAtHome] = useState(isHome);

  useEffect(() => {
    const onMenuData = (event: Event) => {
      const detail = (event as CustomEvent<LanguageMenuData>).detail;
      if (detail) setData(detail);
    };
    const onNavigated = () => {
      setOpen(false);
      setAtHome(
        document.querySelector(".page-root")?.classList.contains("home") ??
          false,
      );
    };
    window.addEventListener("frame:language-menu", onMenuData);
    window.addEventListener("frame:navigated", onNavigated);
    return () => {
      window.removeEventListener("frame:language-menu", onMenuData);
      window.removeEventListener("frame:navigated", onNavigated);
    };
  }, []);

  if (data.links.length <= 1) return null;
  return (
    <div className="language-menu">
      <Popover.Root open={open} onOpenChange={setOpen}>
        <Popover.Trigger className="language-menu__button">
          <span aria-hidden="true">🌐</span> {languageName(data.language)}
        </Popover.Trigger>
        <Popover.Portal>
          <Popover.Positioner
            className="language-menu__positioner"
            side="bottom"
            align={atHome ? "start" : "end"}
            sideOffset={4}
            positionMethod="absolute"
          >
            <Popover.Popup className="language-menu__panel" render={<ul />}>
              {data.links.map((link) => (
                <li key={link.language}>
                  {link.href === null ? (
                    <span aria-current="true">
                      {languageName(link.language)}
                    </span>
                  ) : (
                    <a
                      href={link.href}
                      hrefLang={link.language}
                      lang={link.language}
                    >
                      {languageName(link.language)}
                    </a>
                  )}
                </li>
              ))}
            </Popover.Popup>
          </Popover.Positioner>
        </Popover.Portal>
      </Popover.Root>
    </div>
  );
}
