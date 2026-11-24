import type { ReactNode } from "react";
import LanguageDocument from "../../components/LanguageDocument";

export default function Layout({ children }: { children: ReactNode }) {
  return <LanguageDocument language="en">{children}</LanguageDocument>;
}
