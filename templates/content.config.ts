import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const base = "./md";
// A date as the front matter carries it: an ISO 8601 string
// or a YAML date, normalized here to a string. A string that
// is not a date — the converter's "unknown", for a page with
// no known date, is the one case — fails the build here,
// naming the file, instead of crashing a presenter later.
const dateLike = z
  .union([z.iso.datetime({ offset: true }), z.date()])
  .transform((v) => (v instanceof Date ? v.toISOString() : v));

const pages = defineCollection({
  loader: glob({
    pattern: "**/*.md",
    base,
    // The default entry id is the front matter slug, which names the
    // page rather than the file — and the same page exists once per
    // language. Ids must therefore come from the file path, language
    // directory included, or the versions would collapse into one.
    generateId: ({ entry }) => entry.replace(/\.md$/, ""),
  }),
  schema: z.discriminatedUnion("kind", [
    z.object({
      kind: z.literal("article"),
      title: z.string(),
      slug: z.string(),
      author: z.string(),
      creation_date: dateLike,
      modified_date: dateLike,
      language: z.string(),
      original_language: z.string().optional(),
      translation: z.boolean().default(false).optional(),
      listed: z.boolean().default(true).optional(),
    }),
    z.object({
      kind: z.literal("redirect"),
      title: z.string(),
      slug: z.string(),
      target_slug: z.string(),
    }),
    z.object({
      kind: z.literal("special"),
      title: z.string(),
      slug: z.string(),
      // The converter omits the key when the site has no language;
      // missingVersions in i18n.ts treats such a page the same way.
      language: z.string().optional(),
    }),
  ]),
});

export const collections = { pages };
