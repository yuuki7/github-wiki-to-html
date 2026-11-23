import PathPage, { pathsForLanguage } from "../../../components/PathPage";

// The English pages: every path the route table serves in
// English — the home page, the /en paths, and the English
// originals at the root. They share this directory's layout,
// so moving among them is in-app navigation.

export function generateStaticParams() {
  return pathsForLanguage("en").map((path) => ({ path }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  const { path } = await params;
  return <PathPage segments={path ?? []} />;
}
