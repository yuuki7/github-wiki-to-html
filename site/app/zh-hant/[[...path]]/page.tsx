import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The Traditional Chinese pages: every path the route table serves in
// Traditional Chinese, under its /zh-hant prefix.

export function generateStaticParams() {
  return pathsForLanguage("zh-hant")
    .filter((path) => path[0] === "zh-hant")
    .map((path) => ({ path: path.slice(1) }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={["zh-hant", ...(path ?? [])]} />;
}
