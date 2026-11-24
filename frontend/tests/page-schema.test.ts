import assert from "node:assert/strict";
import test from "node:test";
import { parsePageData } from "../lib/page-schema.ts";

const article = {
  kind: "article",
  title: "Example",
  slug: "Example",
  author: "Yuuki",
  creation_date: "2025-01-01T00:00:00Z",
  modified_date: "2025-01-02T00:00:00Z",
  language: "en",
};

test("normalizes optional article defaults", () => {
  assert.deepEqual(parsePageData(article, "en/Example.md"), {
    ...article,
    translation: false,
    listed: true,
  });
});

test("rejects unknown metadata instead of silently stripping it", () => {
  assert.throws(
    () => parsePageData({ ...article, modified: "yesterday" }, "en/Example.md"),
    /en\/Example\.md: invalid front matter: .*Unrecognized key/,
  );
});

test("rejects empty required identifiers with the source path", () => {
  assert.throws(
    () => parsePageData({ ...article, slug: "" }, "en/Example.md"),
    /en\/Example\.md: invalid front matter: slug:/,
  );
});

test("rejects unknown page kinds", () => {
  assert.throws(
    () => parsePageData({ ...article, kind: "redirect" }, "en/Example.md"),
    /en\/Example\.md: invalid front matter:/,
  );
});
