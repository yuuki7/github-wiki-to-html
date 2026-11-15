import type { CollectionEntry } from "astro:content";

// One entry of the pages collection, and the article form of
// it, for the places that work with articles only.
export type PageEntry = CollectionEntry<"pages">;
export type ArticleEntry = PageEntry & {
  data: Extract<PageEntry["data"], { kind: "article" }>;
};

export interface ArticleMetaProps {
  author: string;
  creationDate: string;
  modifiedDate?: string;
  language?: string;
  // Set when the page is a translation: the language the original
  // is written in and the original's URL, so the header can state
  // the page's provenance next to its byline.
  translation?: {
    originalLanguage: string;
    originalHref: string;
  };
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
  // The page's canonical URL, absolute. A redirect stub has no
  // canonical version of its own, so it points this at its target.
  canonical?: string;
  // The page's Open Graph type: "article" for an article page,
  // "website" for a home page. Redirect stubs set neither this
  // nor the tags that go with it.
  ogType?: "article" | "website";
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
