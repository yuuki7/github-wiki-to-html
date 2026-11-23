import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The German pages: every path the route table serves in
// German, under its /de prefix.

export function generateStaticParams() {
  return pathsForLanguage("de")
    .filter((path) => path[0] === "de")
    .map((path) => ({ path: path.slice(1) }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={["de", ...(path ?? [])]} />;
}
