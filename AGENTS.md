# Instructions for coding agents

## Start here

- Read `README.md`, this file, and the relevant task definitions in `Rakefile` before changing code or running builds.
- Work on the requested non-`main` branch/worktree. Do not push or create a PR unless Yuuki explicitly asks.
- Keep reports and questions to Yuuki in Japanese.
- Review broadly before focusing on a subsystem. Cite the code or source that supports review conclusions.
- Do not dismiss a concern as a design judgment; explain the tradeoff and consult Yuuki when the intended behavior is unclear.

## Build inputs and commands

Do not confuse the site-only build with the complete build:

- `bundle exec rake build` runs `build:convert` followed by `build:site`. It reads the wiki submodule, `translations/`, and `site.json`, regenerates `md/`, then builds `frontend/out/`. Conversion synchronizes `yuukinder.wiki/META.md` and writes `.cache/head`; inspect these source-side effects after the command.
- `bundle exec rake build:convert` runs only the conversion stage. It does not build HTML.
- `bundle exec rake build:site` reads only the existing `md/` tree and builds `frontend/out/`. It does not read `translations/` or refresh `md/`. Use it only when the converted Markdown is already current and complete. A missing-translation failure in this task may reflect stale/incomplete `md/`; check the full `bundle exec rake build` path before attributing the failure to missing tracked translation sources.
- `bundle exec rake server` serves the existing `frontend/out/`; it does not build or convert anything.
- `bundle exec rake` with no task is the default setup task, not the site build.

Setup and verification:

- `bundle exec rake setup` installs Ruby dependencies, the RBS collection, and npm dependencies. Run once in a worktree or when dependency files change. Node.js `>=26` is required.
- `bundle exec rake check` runs Ruby lint/signature/type checks and TypeScript type checking. It regenerates `sig/generated/`; include any relevant generated signature changes with Ruby changes.
- `bundle exec rake check:ruby` and `bundle exec rake check:ts` run the respective checks.
- `bundle exec rake test` runs both RSpec and TypeScript tests. `bundle exec rake test:ts` runs only TypeScript tests.
- Standard full verification: `bundle exec rake check && bundle exec rake test && bundle exec rake build`.
- Frontend-only verification when `md/` is complete/current: `bundle exec rake check:ts test:ts build:site`.
- Do not run `bundle exec rake docs` unless requested; it regenerates the tracked `docs/` tree and can create a large diff.
- Do not use raw `npm run build` as the project-level build command. Use the Rake task so its scope is explicit. The lower-level commands are defined in `package.json` and are invoked by Rake.

Do not add or run tests unless Yuuki asks for test/verification or the requested change requires validation. When tests are part of the request, add them at the appropriate layer and use the Rake task.

## Code and type-checking conventions

- Frontend source is under `frontend/`; TypeScript type checking uses `frontend/tsconfig.json`. Preserve strictness, including `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`; do not weaken compiler options to silence errors.
- TypeScript tests live in `frontend/tests/` and use Node's built-in test runner. Keep the test command in `package.json` and its Rake entry in sync.
- Ruby type information lives in `# rbs_inline:` annotations in `lib/*.rb`; keep signatures in sync with implementation.
- Avoid `untyped` in RBS. Use aliases in `sig/wikinder.rbs` to keep annotations readable.
- Handwritten dependency signatures in `sig/` must describe the dependency's actual API, not a narrower call-site-specific subset. Keep them even when currently unused.
- Temporarily ignore only RuboCop Metrics offenses when needed; do not suppress other offenses.
- Do not parse HTML with regular expressions; use an HTML parser/AST.
- Judge Markdown-to-Markdown behavior by reparsing the result with the downstream parser, not by inspecting output strings alone.
- Wiki editors are an uncontrolled public. Support realistic syntax unless evidence or an explicit scope decision says otherwise.

## Evidence and behavior decisions

Use evidence in this order:

1. Behavior Yuuki has empirically verified on the live GitHub Wiki.
2. Local experiments and primary sources, including installed Gollum sources and their tests. Ruby gems are vendored under `vendor/bundle/ruby/4.0.0/gems/` in this worktree; do not assume the system gem directory is the active source.
3. A reasoned project-specific behavior where upstream behavior is demonstrably defective or unsuitable.

Agents do not verify behavior against the live GitHub Wiki; Yuuki does. Search-engine summaries are not evidence. `yuukinder.wiki/` is a test corpus, not grounds for restricting supported syntax or setting severity.

Settled findings—do not re-litigate without new evidence:

- Markdown wikilink pipe order is `[[Display|Target]]`; piped images use `[[Path|Caption]]`. This follows Gollum's positional parsing; `reverse_links` applies to Creole/MediaWiki, not Markdown, and agrees with live-wiki behavior.
- Rugged `a.diff(b)` treats `a` as the old side; `commit.diff(parent)` is chronologically reversed. The rename-map comments in `lib/` rely on this behavior.
- CommonMarker 2.x source positions use 1-based byte columns; `end_column` is the last byte's column, inclusive.
- When testing Gollum with CommonMarker 2.x, replace the complete `GitHub::Markup::Markdown::MARKDOWN_GEMS` map with the CommonMarker 2.x adapter. `github-markup` 4.0.1 calls the old `CommonMarker.render_html` API, whereas CommonMarker 2.x uses `Commonmarker.to_html`; keeping other renderers in the map permits fallback and invalidates the experiment.
- `bin/convert.rb` is not type-checked. Adding a top-level script to Steep does not provide meaningful checking for its constants or `JSON.parse` values; do not claim that adding it to the target closes that gap.

## Changes and commits

- Do not alter `main` for work assigned to another branch.
- Leave changes uncommitted unless Yuuki explicitly authorizes commits. Authorization to commit does not authorize pushing or PR creation.
- Keep generated files and build side effects only when they are relevant to the requested change; inspect `git status` after Rake tasks.
- When a previous answer was wrong, state the corrected conclusion directly and continue from the actual evidence.
