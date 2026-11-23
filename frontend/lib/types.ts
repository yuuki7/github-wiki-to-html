// The data one content file carries, by the kind of page it
// is. The converter writes these as YAML front matter; the
// content layer (lib/content.ts) validates every file against
// the same shapes.
export interface ArticleData {
  kind: "article";
  title: string;
  slug: string;
  author: string;
  creation_date: string;
  modified_date: string;
  language: string;
  original_language?: string;
  translation?: boolean;
  listed?: boolean;
}

export interface RedirectData {
  kind: "redirect";
  title: string;
  slug: string;
  target_slug: string;
}

export interface SpecialData {
  kind: "special";
  title: string;
  slug: string;
  // The converter omits the key when the site has no language;
  // missingVersions in i18n.ts treats such a page the same way.
  language?: string;
}

export type PageData = ArticleData | RedirectData | SpecialData;

// One entry of the pages collection: a content file, its
// validated front matter, and its Markdown body.
export interface PageEntry {
  // The file's path under md/, language directory included,
  // without the extension: "en/Bear-arithmetic". The same page
  // exists once per language, so ids must come from the file
  // path, or the versions would collapse into one.
  id: string;
  filePath: string;
  data: PageData;
  body: string;
}

// The article form of an entry, for the places that work with
// articles only.
export type ArticleEntry = PageEntry & { data: ArticleData };

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
  // Whether the page loads the site's scripts (MathJax; the AI
  // assistant is a component of the page itself). Real pages do;
  // redirect stubs, which send the reader elsewhere at once,
  // do not.
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
