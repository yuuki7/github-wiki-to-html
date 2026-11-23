import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The Chinese pages: every path the route table serves in
// Chinese, under its /zh prefix.

export function generateStaticParams() {
  return pathsForLanguage("zh")
    .filter((path) => path[0] === "zh")
    .map((path) => ({ path: path.slice(1) }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={["zh", ...(path ?? [])]} />;
}
