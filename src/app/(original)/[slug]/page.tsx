import PathPage from "../../../components/PathPage";
import { defaultLanguage } from "../../../lib/i18n";
import { routeTable } from "../../../lib/routes";

// The root-level originals in a language other than the
// default: the one-segment article paths, each served in
// its own language (see this directory's layout). The
// default language's originals are served by the (en)
// directory instead, with the home page and the /en paths,
// so that moving among them is in-app navigation.

export function generateStaticParams() {
  return [...routeTable().entries()]
    .filter(
      ([path, route]) =>
        route.type === "article" &&
        route.lang !== defaultLanguage &&
        path !== "" &&
        !path.includes("/"),
    )
    .map(([path]) => ({ slug: path }));
}

export default async function Page({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  return <PathPage segments={[slug]} />;
}
