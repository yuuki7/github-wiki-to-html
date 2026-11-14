# AGENTS.md

## Build and Test Commands

- `bundle exec rake` — Install the dependencies. First setup only, or when dependency files change.
- `bundle exec rake check` — Run the linter and type checks. Also regenerates `sig/generated/` from the inline annotations in `lib/`; commit the regeneration together with the `lib/` change. Ignore RuboCop Metrics offenses; do not ignore any other offenses.
- `bundle exec rake test` — Run the tests.
- `bundle exec rake build` — Build the site. Side effect: `bin/convert.rb` rewrites `META.md` in the real wiki repository.
- Do not run `bundle exec rake docs` — it would regenerate `docs/` and bloat the diff. Keep diffs concise.

The standard verification sequence is `bundle exec rake check && bundle exec rake test && bundle exec rake build`.

Gotchas:

- Type information lives in `# rbs_inline:` annotations inside `lib/*.rb`, not in separate RBS files; keep them in sync with the code or `rake check` fails.
- Avoid `untyped` as much as possible.
- Keep inline type declarations from becoming verbose by defining type aliases in `sig/wikinder.rbs`.

## How to Judge Behaviour

In order of precedence:

1. Behaviour Yuuki has empirically verified on the real GitHub Wiki
2. Local verification: running the code and reading sources such as the gollum-lib 6.1.0 and gollum-rugged_adapter 3.0 source code, installed locally under `/opt/homebrew/lib/ruby/gems/4.0.0/gems/`
3. Our own reasonable behaviour, as an exception, where the GitHub Wiki or gollum-lib behaviour appears to be a bug or an edge case

- Verification is primarily local: reading source code such as gollum-lib and gollum-rugged_adapter and running commands. Verification against the live GitHub Wiki is done by Yuuki, not by agents. A search-engine summary is not evidence.
- Wiki editors are an uncontrolled general public, so all realistic and reasonable syntax must basically be supported.
- A test wiki, including `yuukinder.wiki`, is only a test corpus. Never use the presence or absence of a construct in it as grounds for scope or severity.

Settled questions — do not re-litigate:

- Wikilink pipe order is `[[Display|Target]]`; piped images are the reverse (`[[Path|Caption]]`). Verified against gollum-lib's own tests (positional parsing — `reverse_links` applies only to creole/mediawiki, and we support Markdown only) and consistent with live-wiki rendering.
- Rugged's `a.diff(b)` treats `a` as the old side, so `commit.diff(parent)` is chronologically reversed — the rename-map comment in `wiki.rb` is correct as written.
- CommonMarker 2.x `source_position` values are 1-based byte columns; `end_column` is the column of the last byte, inclusive.
- For local tests with gollum-lib, its Markdown renderer must be replaced with commonmarker 2.x. github-markup 4.0.1 (a gollum-lib 6.1.0 dependency) calls `CommonMarker.render_html`, but in commonmarker 2.x the class is `Commonmarker` and the method is `to_html`. Replace the whole `MARKDOWN_GEMS` hash so that no other renderer can be selected by fallback:

  ```ruby
  GitHub::Markup::Markdown::MARKDOWN_GEMS.replace(
    'commonmarker' => proc { |content, options: {}|
      Commonmarker.to_html(
        content,
        options: {
          render: { unsafe: true, hardbreaks: false, gfm_quirks: true, escaped_char_spans: false },
          extension: {
            math_dollars: true,
            math_code: true,
            strikethrough: true,
            tagfilter: true,
            table: true,
            autolink: true,
            tasklist: true,
            footnotes: true
          }
        },
        plugins: { syntax_highlighter: nil }
      )
    }
  )
  ```

## Working Principles

- Never parse HTML with regular expressions. Use a parser.
- For Markdown-to-Markdown conversion, judge the result after re-parsing it downstream, not from the output string alone.
- Review broadly first, deeply second. Tunnel vision on a single interesting point is the failure mode to guard against.
- Cite the source of every conclusion.
- Do not dismiss a point as mere design judgment; raise it as a design problem and consult Yuuki. Design is an important part of this project.
- When an answer contained an error, skip the apology and reconstruct the correct answer.
- Commit and push only when Yuuki explicitly instructs it. Until then, leave changes uncommitted so that everything lands in a single commit.
- Reports and consultation with Yuuki are in Japanese.
