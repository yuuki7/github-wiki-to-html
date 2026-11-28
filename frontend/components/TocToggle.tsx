// The menu's control at the head of the article's title:
// a button wearing Lucide's table-of-contents, which the
// stylesheet mirrors left-to-right. The menu itself, as
// a panel over the page, is the frame's drawer (see
// TocDrawer); this button is its toggle wherever the
// menu has no control of its own in the layout — on a
// narrow screen always, the bottom bar holding no button
// for the menu, and on a wide screen while the AI panel
// stands and the sidebar is folded away — and the
// stylesheet shows it in those states only. Its icon
// follows the menu's state in the stylesheet: the table
// of contents while the menu is closed, a cross while it
// stands.
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
