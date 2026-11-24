import { absoluteUrl, uiFor } from "../lib/i18n";
import type { RedirectProps } from "../lib/types";
import BaseHead from "./BaseHead";

// A redirect stub: a minimal page that sends the reader to
// its target at once. It loads no scripts; its head points
// the canonical URL at the target, and a meta refresh follows
// the link it shows.

export default function RedirectStub({
  title,
  language = "en",
  targetHref,
}: RedirectProps) {
  const ui = uiFor(language);
  return (
    <>
      <BaseHead
        title={title}
        language={language}
        canonical={absoluteUrl(targetHref)}
      >
        <meta name="robots" content="noindex" />
        <meta httpEquiv="refresh" content={`0; url=${targetHref}`} />
      </BaseHead>

      <p>
        <a href={targetHref}>{ui.redirect}</a>
      </p>
    </>
  );
}
