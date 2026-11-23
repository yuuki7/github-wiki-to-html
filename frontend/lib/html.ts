// Escapes a string for use as HTML text or in a quoted
// attribute value. The views build a few small fragments —
// the footer's edit link — as HTML strings, because the
// fragment they extend is itself rendered HTML.
export const escapeHtml = (value: string): string =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
