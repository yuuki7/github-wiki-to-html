import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const base = './md';
const isoDate = z
  .union([z.string(), z.date()])
  .transform((v) => (v instanceof Date ? v.toISOString() : v));

const pages = defineCollection({
  loader: glob({ pattern: '*.md', base }),
  schema: z.discriminatedUnion('kind', [
    z.object({
      kind: z.literal('article'),
      title: z.string(),
      slug: z.string(),
      author: z.string(),
      creation_date: isoDate,
      modified_date: isoDate,
      language: z.string(),
      listed: z.boolean().default(true).optional(),
    }),
    z.object({
      kind: z.literal('redirect'),
      title: z.string(),
      slug: z.string(),
      target_slug: z.string(),
    }),
    z.object({
      kind: z.literal('special'),
      title: z.string(),
      slug: z.string(),
      language: z.string(),
    }),
  ]),
});

export const collections = { pages };
