import assert from "node:assert/strict";
import test from "node:test";
import { renderMarkdown, smartify } from "../lib/markdown.ts";

test("smartify converts dashes, ellipsis, and quotes", () => {
  assert.equal(smartify("a---b -- c..."), "a—b – c…");
  assert.equal(smartify('"hello"'), "“hello”");
  assert.equal(smartify("it's 'fine'"), "it’s ‘fine’");
  assert.equal(smartify('日本語"English"テスト'), "日本語“English”テスト");
});

test("renderMarkdown extracts h2-h6 headings and skips h1", async () => {
  const md = [
    "# Top Title",
    "",
    "## First Section",
    "",
    "### Subsection",
    "",
    "Body text.",
  ].join("\n");

  const result = await renderMarkdown(md, process.cwd());
  assert.deepEqual(result.headings, [
    { depth: 2, slug: "first-section", text: "First Section" },
    { depth: 3, slug: "subsection", text: "Subsection" },
  ]);
});
