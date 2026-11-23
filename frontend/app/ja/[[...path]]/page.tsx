import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The Japanese pages: every path the route table serves in
// Japanese, under its /ja prefix.

export function generateStaticParams() {
  return pathsForLanguage("ja")
    .filter((path) => path[0] === "ja")
    .map((path) => ({ path: path.slice(1) }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={["ja", ...(path ?? [])]} />;
}
