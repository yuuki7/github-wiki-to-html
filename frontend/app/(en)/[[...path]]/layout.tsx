import type { ReactNode } from "react";
import LanguageRouteLayout from "../../../components/LanguageRouteLayout";

export default function Layout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ path?: string[] }>;
}) {
  return (
    <LanguageRouteLayout language="en" prefixed={false} params={params}>
      {children}
    </LanguageRouteLayout>
  );
}
