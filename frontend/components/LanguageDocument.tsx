import type { ReactNode } from "react";
import { directionFor } from "../lib/i18n";

export default function LanguageDocument({
  language,
  children,
}: {
  language: string;
  children: ReactNode;
}) {
  return (
    <html lang={language} dir={directionFor(language)}>
      <body>{children}</body>
    </html>
  );
}
