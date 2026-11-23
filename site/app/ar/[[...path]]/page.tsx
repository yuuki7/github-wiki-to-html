import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The Arabic pages: every path the route table serves in
// Arabic, under its /ar prefix.

export function generateStaticParams() {
  return pathsForLanguage("ar")
    .filter((path) => path[0] === "ar")
    .map((path) => ({ path: path.slice(1) }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={["ar", ...(path ?? [])]} />;
}
