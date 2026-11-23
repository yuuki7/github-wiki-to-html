import type { ReactNode } from "react";
import RouteShell from "../../../components/RouteShell";

// The Arabic pages' head and shell, inside this directory's
// document. The layout knows the path, so it — not the page —
// renders what frames the page, and the frame stays in place
// while the reader moves between pages.

export default async function Layout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <RouteShell segments={["ar", ...(path ?? [])]}>{children}</RouteShell>;
}
