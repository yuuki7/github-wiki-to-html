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
  // Whether the page loads the site's scripts (the AI
  // assistant and MathJax). Real pages do; redirect stubs,
  // which send the reader elsewhere at once, do not.
  scripts?: boolean;
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
  // The language of the version the stub stands in for. The
  // stub's only text is its redirect link, written in that
  // language, and the document itself is in it too: its lang
  // and dir are the reader's context. Callers pass the
  // language; the component's default only covers a caller
  // that does not know it.
  language?: string;
  // The URL of the target page's best version (the version in the
  // redirect's own language when one exists, the original otherwise),
  // already resolved to the version's own URL form.
  targetHref: string;
};
