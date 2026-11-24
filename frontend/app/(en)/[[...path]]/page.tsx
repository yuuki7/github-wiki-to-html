import LanguageRoutePage, {
  languageStaticParams,
} from "../../../components/LanguageRoutePage";

export function generateStaticParams() {
  return languageStaticParams("en", false);
}

export default function Page({
  params,
}: {
  params: Promise<{ path?: string[] }>;
}) {
  return <LanguageRoutePage language="en" prefixed={false} params={params} />;
}
