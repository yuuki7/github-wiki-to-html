# Instructions for coding agents

## Build and test commands

See `README.md` (Usage) for the commands themselves; this section only adds what the README does not say.

- With no task, `bundle exec rake` runs the default setup task; it is not a build.
- `bundle exec rake check` also regenerates `sig/generated/` from the inline annotations in `lib/`; commit the regeneration together with the `lib/` change.
- Temporarily ignore RuboCop Metrics offenses; do not ignore any other offenses.
- After `bundle exec rake build`, inspect its source-side effects: the wiki's `META.md`, `md/` and `.cache/head`.
- A missing-translation failure in `bundle exec rake build:site` may reflect a stale or incomplete `md/`; check the full `bundle exec rake build` path before attributing the failure to the tracked translation sources.
- Do not run `bundle exec rake docs` unless asked; it regenerates the tracked `docs/` tree and bloats the diff. Keep diffs concise.
- Do not use raw `npm run build` as the project-level build command. Use the Rake task so its scope is explicit.

The standard verification sequence is `bundle exec rake check && bundle exec rake test && bundle exec rake build`.

Gotchas:

- Type information lives in `# rbs_inline:` annotations inside `lib/*.rb`, not in separate RBS files; keep them in sync with the code or `rake check` fails.
- Avoid `untyped` as much as possible.
- Keep inline type declarations from becoming verbose by defining type aliases in `sig/wikinder.rbs`.
- Signatures in `sig/` for a library (for example `rugged.rbs`) must match the library's actual API, independently of how this project uses it. Do not narrow a type to what the current call sites happen to need.
- Hand-written signatures in `sig/` for libraries that are not our own module (for example `gollum-lib.rbs` and `github/markup.rbs`) are kept even when nothing currently uses them. Do not remove them as dead code.
- Frontend source is under `frontend/`; TypeScript type checking uses `frontend/tsconfig.json`. Preserve its strictness, including `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`; do not weaken compiler options to silence errors.
- TypeScript tests live in `frontend/tests/` and use Node's built-in test runner. Keep the test command in `package.json` and its Rake entry in sync.

## How to judge behaviour

In order of precedence:

1. Behaviour Yuuki has empirically verified on the real GitHub Wiki
2. Local verification: running the code and reading sources such as the gollum-lib 6.1.0 and gollum-rugged_adapter 3.0 source code, vendored locally under `vendor/bundle/ruby/4.0.0/gems/` in each worktree
3. Our own reasonable behaviour, as an exception, where the GitHub Wiki or gollum-lib behaviour appears to be a bug or an edge case

- Verification is primarily local: reading source code such as gollum-lib and gollum-rugged_adapter and running commands. Verification against the live GitHub Wiki is done by Yuuki, not by agents. A search-engine summary is not evidence.
- Wiki editors are an uncontrolled general public, so all realistic and reasonable syntax must basically be supported.
- A test wiki, including `yuukinder.wiki`, is only a test corpus. Never use the presence or absence of a construct in it as grounds for scope or severity.

Settled questions — do not re-litigate:

- `bin/convert.rb` is not type-checked, and adding it to a Steep target would not close any gap. RBS describes classes and modules; a top-level script's constants have no declarations (Steep reports them all as unknown constants), and the values the script passes to `Wiki.new` come from `JSON.parse`, whose result is untyped, so Steep cannot check that flow either.
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

## Working principles

- Work on the requested branch or worktree. Do not alter `main` for work assigned to another branch.
- Never parse HTML with regular expressions. Use a parser.
- For Markdown-to-Markdown conversion, judge the result after re-parsing it downstream, not from the output string alone.
- Review broadly first, deeply second. Tunnel vision on a single interesting point is the failure mode to guard against.
- Cite the source of every conclusion.
- Do not dismiss a point as mere design judgment; raise it as a design problem and consult Yuuki. Design is an important part of this project.
- When an answer contained an error, skip the apology and reconstruct the correct answer.
- Keep generated files and build side effects only when they are relevant to the requested change; inspect `git status` after Rake tasks.
- Commit and push only when Yuuki explicitly instructs it, and do not create a PR unless Yuuki explicitly asks. Until then, leave changes uncommitted so that everything lands in a single commit.
- Reports and consultation with Yuuki are in Japanese.
