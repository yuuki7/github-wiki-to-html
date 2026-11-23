import type { ReactNode } from "react";
import RouteShell from "../../../components/RouteShell";
import { defaultLanguage, directionFor } from "../../../lib/i18n";
import { routeFor } from "../../../lib/routes";

// The document of a root-level original. An original is
// served at the root in its own language, whichever that is,
// so this layout reads the language from the route table.
// The route's head and shell are rendered here too, as in
// every layout, so the frame stays in place while the reader
// moves between pages.

export default async function Layout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const lang = routeFor([decodeURIComponent(slug)])?.lang ?? defaultLanguage;
  return (
    <html lang={lang} dir={directionFor(lang)}>
      <body>
        <RouteShell segments={[slug]}>{children}</RouteShell>
      </body>
    </html>
  );
}
