import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const base = "./md";
const isoDate = z
  .union([z.string(), z.date()])
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
      creation_date: isoDate,
      modified_date: isoDate,
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
      language: z.string(),
    }),
  ]),
});

export const collections = { pages };
