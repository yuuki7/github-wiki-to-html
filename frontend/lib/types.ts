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
  original_language?: string | undefined;
  translation?: boolean | undefined;
  listed?: boolean | undefined;
}

export interface RedirectData {
  kind: "redirect";
  title: string;
  slug: string;
  target_slug: string;
  // The language the target's body had under this old name,
  // recorded on the name's META.md row by the converter.
  language: string;
}

export interface SpecialData {
  kind: "special";
  title: string;
  slug: string;
  // The converter omits the key when the site has no language;
  // missingVersions in i18n.ts treats such a page the same way.
  language?: string | undefined;
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

// The strings the AI assistant needs, in its own terms. They are
// derived from UiStrings, which names the same texts in the
// site's interface vocabulary.
export interface AiStrings {
  summarize: string;
  loading: string;
  send: string;
  unsupported: string;
  error: string;
}

// The one redirect stub: its title, the language its link is
// written in, and the target URL already resolved to the
// version's own URL form. The stub has no canonical page of
// its own and no page-specific head tags; the target's URL is
// its canonical instead.
export interface RedirectProps {
  title: string;
  // The version the stub stands in for. The component's default
  // only covers a caller that does not know the language.
  language?: string;
  targetHref: string;
}
