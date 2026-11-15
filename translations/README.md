# Translations

Translated pages live here as data, one directory per language:

```
translations/<language>/<Slug>.md
```

- `<language>` is one of the site's languages (see `languages` in `site.json`): `en`, `zh`, `zh-hant`, `ar`, `ja`, `de`.
- `<Slug>` is the slug of the original page, unchanged. `Home.md` and `_Footer.md` translate the special pages.
- The body is Markdown in the same wiki dialect as the original pages. Wikilinks (`[[...]]`) are resolved for the translation's language when the page is built: a link points at the same-language version of its target when one exists, and at the original otherwise.
- A file may start with a YAML front matter block. The only key the converter reads is `title`, the page's title in the translated language:

  ```markdown
  ---
  title: Über uns
  ---

  Body text…
  ```

- Author and dates are taken from the original page, not from the translation file.
- A translation is skipped (with a warning) when its language is not supported, when no original page has its slug, or when it is written in the original page's own language.

`bin/convert.rb` reads this directory on every build. Nothing here is generated; files are added and edited by hand (or by a translating agent).
