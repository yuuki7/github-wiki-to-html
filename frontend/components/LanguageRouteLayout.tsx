import type { ReactNode } from "react";
import RouteShell from "./RouteShell";

export default async function LanguageRouteLayout({
  language,
  prefixed,
  children,
  params,
}: {
  language: string;
  prefixed: boolean;
  children: ReactNode;
  params: Promise<{ path?: string[] }>;
}) {
  const { path = [] } = await params;
  return (
    <RouteShell segments={prefixed ? [language, ...path] : path}>
      {children}
    </RouteShell>
  );
}
