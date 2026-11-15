import site from "../site.json";

// The site's languages, from the hand-maintained site metadata. The
// default language is the one the original special pages belong to;
// every other language exists once pages are translated into it.
export const defaultLanguage: string = site.language ?? "en";
export const supportedLanguages: string[] =
  Array.isArray(site.languages) && site.languages.length > 0
    ? site.languages
    : [defaultLanguage];

const RTL_BASE_LANGUAGES = new Set(["ar", "fa", "he", "ur"]);

// The writing direction of a language: right-to-left for Arabic and
// its RTL peers, left-to-right for everything else.
export function directionFor(language: string): "rtl" | "ltr" {
  return RTL_BASE_LANGUAGES.has(language.split("-")[0]) ? "rtl" : "ltr";
}

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  "zh-Hans": "简体中文",
  "zh-Hant": "繁體中文",
  ar: "العربية",
  ja: "日本語",
  de: "Deutsch",
};

// A language's own name for itself, for the language switcher.
export function languageName(language: string): string {
  return LANGUAGE_NAMES[language] ?? language;
}

export interface UiStrings {
  editOnWiki: string;
  byline: string;
  translationNotice: string;
  originalArticle: string;
}

const UI_STRINGS: Record<string, UiStrings> = {
  en: {
    editOnWiki: "Edit this page on GitHub Wiki",
    byline: "by",
    translationNotice: "This page is a translation of the original article.",
    originalArticle: "Read the original article",
  },
  ja: {
    editOnWiki: "GitHub Wikiでこのページを編集",
    byline: "著者",
    translationNotice: "このページは原文の翻訳です。",
    originalArticle: "原文を読む",
  },
  de: {
    editOnWiki: "Diese Seite im GitHub Wiki bearbeiten",
    byline: "von",
    translationNotice:
      "Diese Seite ist eine Übersetzung des Originalartikels.",
    originalArticle: "Originalartikel lesen",
  },
  "zh-Hans": {
    editOnWiki: "在 GitHub Wiki 上编辑此页",
    byline: "作者",
    translationNotice: "本页是原文的翻译。",
    originalArticle: "阅读原文",
  },
  "zh-Hant": {
    editOnWiki: "在 GitHub Wiki 上編輯此頁",
    byline: "作者",
    translationNotice: "本頁是原文的翻譯。",
    originalArticle: "閱讀原文",
  },
  ar: {
    editOnWiki: "حرر هذه الصفحة على GitHub Wiki",
    byline: "بقلم",
    translationNotice: "هذه الصفحة ترجمة للمقال الأصلي.",
    originalArticle: "اقرأ المقال الأصلي",
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
