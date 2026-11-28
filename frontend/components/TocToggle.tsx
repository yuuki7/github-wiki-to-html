// The menu's control while the AI panel stands on a wide
// screen: a button at the head of the article's title,
// wearing Lucide's table-of-contents. The menu itself
// leaves the page's layout while the panel stands, and
// opens as a drawer over the article (see TocDrawer);
// this button is its toggle there, as the bottom bar's
// Contents button is on a narrow screen, and the
// stylesheet shows it in that one state only. Its icon
// follows the menu's state in the stylesheet, as the
// bar's does: the table of contents while the menu is
// closed, a cross while it stands.
//
// Like the article header's launcher, the button is
// markup and nothing more: the article is swapped for
// the next page's at every in-app navigation (see the
// link interceptor's swap), and a control swapped in
// with the article is inert. The frame works it: the
// drawer hears clicks on this button's class and opens
// or closes itself, and writes this button's expanded
// state onto whichever copy stands at every change of
// the menu's state.

export default function TocToggle({ label }: { label: string }) {
  return (
    <button
      type="button"
      className="toc-toggle"
      aria-label={label}
      aria-expanded="false"
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
