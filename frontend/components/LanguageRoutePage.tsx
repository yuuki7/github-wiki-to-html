import PathPage from "./PathPage";
import { pathsForLanguage } from "../lib/routes";

export function languageStaticParams(language: string, prefixed: boolean) {
  return pathsForLanguage(language)
    .filter((segments) => !prefixed || segments[0] === language)
    .map((segments) => ({
      path: prefixed ? segments.slice(1) : segments,
    }));
}

export default async function LanguageRoutePage({
  language,
  prefixed,
  params,
}: {
  language: string;
  prefixed: boolean;
  params: Promise<{ path?: string[] }>;
}) {
  const { path = [] } = await params;
  return <PathPage segments={prefixed ? [language, ...path] : path} />;
}
