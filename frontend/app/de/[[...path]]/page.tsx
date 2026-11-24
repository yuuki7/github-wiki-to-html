import LanguageRoutePage, {
  languageStaticParams,
} from "../../../components/LanguageRoutePage";

export function generateStaticParams() {
  return languageStaticParams("de", true);
}

export default function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  return <LanguageRoutePage language="de" prefixed params={params} />;
}
