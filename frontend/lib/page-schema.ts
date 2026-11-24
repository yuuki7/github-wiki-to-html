import { z } from "zod";

const requiredText = z.string().min(1);
const dateLike = z.union([
  z.iso.datetime({ offset: false, precision: 0 }),
  z.date().transform((value, context) => {
    if (value.getUTCMilliseconds() !== 0) {
      context.addIssue({
        code: "custom",
        message: "a date with fractional seconds has no canonical form",
      });
      return z.NEVER;
    }
    return value.toTemporalInstant().toString({ smallestUnit: "second" });
  }),
]);

export const pageSchema = z.discriminatedUnion("kind", [
  z
    .object({
      kind: z.literal("article"),
      title: requiredText,
      slug: requiredText,
      author: requiredText,
      creation_date: dateLike,
      modified_date: dateLike,
      language: requiredText,
      original_language: requiredText.optional(),
      translation: z.boolean().default(false).optional(),
      listed: z.boolean().default(true).optional(),
    })
    .strict(),
  z
    .object({
      kind: z.literal("redirect"),
      title: requiredText,
      slug: requiredText,
      target_slug: requiredText,
      language: z.string(),
    })
    .strict(),
  z
    .object({
      kind: z.literal("special"),
      title: requiredText,
      slug: requiredText,
      language: requiredText.optional(),
    })
    .strict(),
]);

export function parsePageData(data: unknown, filePath: string) {
  const parsed = pageSchema.safeParse(data);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map(
        (issue) =>
          `${issue.path.join(".") || "front matter"}: ${issue.message}`,
      )
      .join("; ");
    throw new Error(`${filePath}: invalid front matter: ${issues}`);
  }
  return parsed.data;
}
