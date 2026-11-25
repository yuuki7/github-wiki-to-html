import assert from "node:assert/strict";
import test from "node:test";
import {
  defaultLanguage,
  directionFor,
  isLanguageCode,
  missingVersions,
  supportedLanguages,
} from "../lib/i18n.ts";

test("directionFor returns rtl for RTL base languages and ltr otherwise", () => {
  assert.equal(directionFor("ar"), "rtl");
  assert.equal(directionFor("ar-EG"), "rtl");
  assert.equal(directionFor("en"), "ltr");
  assert.equal(directionFor("ja"), "ltr");
  assert.equal(directionFor("zh-hant"), "ltr");
});

test("isLanguageCode accepts ISO codes and rejects unknown tags", () => {
  assert.equal(isLanguageCode("en"), true);
  assert.equal(isLanguageCode("ja"), true);
  assert.equal(isLanguageCode("zh-hant"), true);
  assert.equal(isLanguageCode("not-a-lang-code"), false);
});

test("missingVersions reports missing translations for originals", () => {
  const entries = [
    { kind: "article", slug: "Hello", language: defaultLanguage },
    ...supportedLanguages
      .filter((lang) => lang !== defaultLanguage && lang !== "ja")
      .map((lang) => ({
        kind: "article",
        slug: "Hello",
        language: lang,
        translation: true,
      })),
  ].map((data) => ({ data }));

  assert.deepEqual(missingVersions(entries), ["Hello (ja)"]);
});
