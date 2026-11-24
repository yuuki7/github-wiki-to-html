import LanguageRoutePage, {
  languageStaticParams,
} from "../../../components/LanguageRoutePage";

export function generateStaticParams() {
  return languageStaticParams("ar", true);
}

export default function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  return <LanguageRoutePage language="ar" prefixed params={params} />;
}
