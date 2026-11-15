export interface ArticleMetaProps {
  author: string;
  creationDate: string;
  modifiedDate?: string;
  language?: string;
}

// One version of a page in one language, for hreflang links and the
// language switcher.
export interface AlternateLink {
  language: string;
  href: string;
}

export interface BaseProps {
  title: string;
  language: string;
  className?: string;
  alternates?: AlternateLink[];
}

export type ArticleProps = BaseProps & {
  isHome?: boolean;
  meta?: ArticleMetaProps;
  languageLinks?: AlternateLink[];
};

export type HomeProps = BaseProps & {
  isHome?: true;
  languageLinks?: AlternateLink[];
};

export type RedirectProps = Omit<BaseProps, "language"> & {
  // A redirect stub's only text is the English word "Redirect", so the
  // component itself supplies the language; callers do not pass one.
  language?: string;
  // The URL of the target page's best version (the version in the
  // redirect's own language when one exists, the original otherwise),
  // already resolved to the version's own URL form.
  targetHref: string;
};
