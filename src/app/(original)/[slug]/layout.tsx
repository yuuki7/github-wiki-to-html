import type { ReactNode } from "react";
import { defaultLanguage, directionFor } from "../../../lib/i18n";
import { routeFor } from "../../../lib/routes";

// The document of a root-level original. An original is
// served at the root in its own language, whichever that is,
// so this layout reads the language from the route table.

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
      <body>{children}</body>
    </html>
  );
}
