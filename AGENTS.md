# AGENTS.md

## Build and Test Commands

- `bundle exec rake` — Install the dependencies. First setup only, or when dependency files change.
- `bundle exec rake check` — Run the linter and type checks. Also regenerates `sig/` from the inline annotations in `lib/`; commit the regeneration together with the `lib/` change.
- `bundle exec rake test` — Run the tests.
- `bundle exec rake build` — Build the site. Side effect: `bin/convert.rb` rewrites `META.md` in the real wiki repository.

The standard verification sequence is `bundle exec rake check && bundle exec rake test && bundle exec rake build`.

Gotchas:

- Type information lives in `# rbs_inline:` annotations inside `lib/*.rb`, not in separate RBS files; keep them in sync with the code or `rake check` fails.

## How to Judge Behaviour

In order of precedence:

1. Behaviour empirically verified on the real GitHub Wiki
2. The gollum-lib source code (6.1.0, installed locally under `/opt/homebrew/lib/ruby/gems/4.0.0/gems/` — read it when applying this criterion)
3. General Markdown practice, only where the above do not decide the question

- Wiki editors are an uncontrolled general public, so all realistic and reasonable syntax must basically be supported.
- A test wiki is only a test corpus. Never use the presence or absence of a construct in it as grounds for scope or severity.
- Do not lower the ambition of the work on grounds of manpower or cost.
- Verification means running the code — locally or against the live GitHub wiki. A search-engine summary is not evidence; it has contradicted the live wiki on the pipe-order question.
- A static-only review is legitimate but ranks below running code, and must be labelled as such.

Settled questions — do not re-litigate:

- Wikilink pipe order is `[[Display|Target]]`; piped images are the reverse (`[[Path|Caption]]`). Verified against gollum-lib's own tests (positional parsing — `reverse_links` applies only to creole/mediawiki) and consistent with live-wiki rendering.
- Rugged's `a.diff(b)` treats `a` as the old side, so `commit.diff(parent)` is chronologically reversed — the rename-map comment in `wiki.rb` is correct as written.
- CommonMarker 2.x `source_position` values are 1-based byte columns; `end_column` is the column of the last byte, inclusive.

## Working Principles

- Never parse HTML with regular expressions. Use a parser.
- For Markdown-to-Markdown conversion, judge the result after re-parsing it downstream, not from the output string alone.
- Review broadly first, deeply second. Tunnel vision on a single interesting point is the failure mode to guard against.
- Verify claims by running the code, and cite the source of every conclusion.
- Do not dismiss a point as mere design judgment; raise it as a design problem and consult Yuuki. Design is an important part of this project.
- When an answer contained an error, skip the apology and reconstruct the correct answer.
- Do not run `bundle exec rake docs` — it would regenerate `docs/` and bloat the diff. Keep diffs concise.
- Commit and push only when Yuuki explicitly instructs it. Until then, leave changes uncommitted so that everything lands in a single commit.
- Reports and consultation with Yuuki are in Japanese.
