import site from "../site.json";

// The site's languages, from the hand-maintained site metadata. The
// default language is the one the original special pages belong to;
// every other language exists once pages are translated into it.
export const defaultLanguage: string = site.language ?? "en";
// In ASCII order of their codes, the order languages are listed
// in everywhere on the site.
export const supportedLanguages: string[] = (
  Array.isArray(site.languages) && site.languages.length > 0
    ? [...site.languages]
    : [defaultLanguage]
).sort();

// A page version, as the content entries carry it. Redirects
// carry no language and are not versions of a page.
export interface PageVersion {
  kind: string;
  slug: string;
  language?: string;
  translation?: boolean;
}

// The versions of pages that are missing from the given entries,
// as "Slug (language)" strings. Every original — an article not
// marked as a translation, or a special page in the default
// language — must exist in every supported language: pages link
// to every language's version unconditionally, so a missing
// version would leave dead links. The build refuses instead.
export function missingVersions(entries: { data: PageVersion }[]): string[] {
  const present = new Set<string>();
  const originals: { slug: string; language: string }[] = [];
  for (const entry of entries) {
    const { kind, slug, language, translation } = entry.data;
    if ((kind !== "article" && kind !== "special") || !language) continue;
    present.add(`${language}/${slug}`);
    if (kind === "article" ? !translation : language === defaultLanguage) {
      originals.push({ slug, language });
    }
  }
  const missing: string[] = [];
  for (const original of originals) {
    for (const language of supportedLanguages) {
      if (
        language !== original.language &&
        !present.has(`${language}/${original.slug}`)
      ) {
        missing.push(`${original.slug} (${language})`);
      }
    }
  }
  return missing.sort();
}

const RTL_BASE_LANGUAGES = new Set(["ar", "fa", "he", "ur"]);

// The writing direction of a language: right-to-left for Arabic and
// its RTL peers, left-to-right for everything else.
export function directionFor(language: string): "rtl" | "ltr" {
  return RTL_BASE_LANGUAGES.has(language.split("-")[0]) ? "rtl" : "ltr";
}

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  "zh": "简体中文",
  "zh-Hant": "繁體中文",
  ar: "العربية",
  ja: "日本語",
  de: "Deutsch",
};

// A language's own name for itself, for the language switcher.
export function languageName(language: string): string {
  return LANGUAGE_NAMES[language] ?? language;
}

// Language names as written in another language, for sentences
// that name a language inside a text in a different one. The
// German forms are the declined names its notice sentence needs.
const LANGUAGE_NAMES_IN: Record<string, Record<string, string>> = {
  en: {
    en: "English",
    "zh": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese",
    ar: "Arabic",
    ja: "Japanese",
    de: "German",
  },
  ja: {
    en: "英語",
    "zh": "中国語（簡体字）",
    "zh-Hant": "中国語（繁体字）",
    ar: "アラビア語",
    ja: "日本語",
    de: "ドイツ語",
  },
  de: {
    en: "Englischen",
    "zh": "Chinesischen (vereinfacht)",
    "zh-Hant": "Chinesischen (traditionell)",
    ar: "Arabischen",
    ja: "Japanischen",
    de: "Deutschen",
  },
  "zh": {
    en: "英语",
    "zh": "简体中文",
    "zh-Hant": "繁体中文",
    ar: "阿拉伯语",
    ja: "日语",
    de: "德语",
  },
  "zh-Hant": {
    en: "英語",
    "zh": "簡體中文",
    "zh-Hant": "繁體中文",
    ar: "阿拉伯語",
    ja: "日語",
    de: "德語",
  },
  ar: {
    en: "الإنجليزية",
    "zh": "الصينية المبسطة",
    "zh-Hant": "الصينية التقليدية",
    ar: "العربية",
    ja: "اليابانية",
    de: "الألمانية",
  },
};

// The name of the target language as written in the given
// language, falling back to the target's own name for itself.
export function languageNameIn(language: string, target: string): string {
  return LANGUAGE_NAMES_IN[language]?.[target] ?? languageName(target);
}

export interface UiStrings {
  editOnWiki: string;
  byline: string;
  translationNotice: (originalLanguageName: string) => string;
  originalArticle: string;
}

const UI_STRINGS: Record<string, UiStrings> = {
  en: {
    editOnWiki: "Edit this page on GitHub Wiki",
    byline: "by",
    translationNotice: (name) => `Translated from ${name}`,
    originalArticle: "Show original",
  },
  ja: {
    editOnWiki: "GitHub Wikiでこのページを編集",
    byline: "著者",
    translationNotice: (name) => `${name}から翻訳`,
    originalArticle: "原文を見る",
  },
  de: {
    editOnWiki: "Diese Seite im GitHub Wiki bearbeiten",
    byline: "von",
    translationNotice: (name) => `Aus dem ${name} übersetzt`,
    originalArticle: "Original anzeigen",
  },
  "zh": {
    editOnWiki: "在 GitHub Wiki 上编辑此页",
    byline: "作者",
    translationNotice: (name) => `译自${name}`,
    originalArticle: "查看原文",
  },
  "zh-Hant": {
    editOnWiki: "在 GitHub Wiki 上編輯此頁",
    byline: "作者",
    translationNotice: (name) => `譯自${name}`,
    originalArticle: "查看原文",
  },
  ar: {
    editOnWiki: "حرر هذه الصفحة على GitHub Wiki",
    byline: "بقلم",
    translationNotice: (name) => `مترجم من ${name}`,
    originalArticle: "عرض الأصل",
  },
};

// The interface strings in a language, falling back to the default
// language for languages without their own set.
export function uiFor(language: string): UiStrings {
  return UI_STRINGS[language] ?? UI_STRINGS[defaultLanguage] ?? UI_STRINGS.en;
}

// The URL of one page in one language. An original page lives at
// the site root; a translation lives under its language.
export function pageHref(
  language: string,
  slug: string,
  translation = false,
): string {
  return translation
    ? `/${language}/${encodeURIComponent(slug)}`
    : `/${encodeURIComponent(slug)}`;
}

// The URL of a language's home page: the site root for the default
// language, the language's code for every other language. The site
// is built as files (one HTML file per page), so the other
// languages' homes are `/ja`, not `/ja/`.
export function homeHref(language: string): string {
  return language === defaultLanguage ? "/" : `/${language}`;
}
