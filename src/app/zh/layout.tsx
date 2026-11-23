import type { ReactNode } from "react";
import { directionFor } from "../../lib/i18n";

// The Chinese document. The site's pages are grouped by the
// language they are served in, so that the document element
// itself carries the page's language and writing direction,
// as it always has.

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh" dir={directionFor("zh")}>
      <body>{children}</body>
    </html>
  );
}
