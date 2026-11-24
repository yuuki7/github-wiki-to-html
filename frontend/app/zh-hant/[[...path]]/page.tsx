import LanguageRoutePage, {
  languageStaticParams,
} from "../../../components/LanguageRoutePage";

export function generateStaticParams() {
  return languageStaticParams("zh-hant", true);
}

export default function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  return <LanguageRoutePage language="zh-hant" prefixed params={params} />;
}
