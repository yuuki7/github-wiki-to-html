# AGENTS.md

## Project Overview

The goal of this project is to develop a tool that converts GitHub Wiki Markdown files into a static HTML website.

This repository is only a rough sketch, predating the production project and its initial commit. Production work is scheduled to begin in April 2027.

GitHub Wiki was originally based on Gollum, but has since diverged from it, and its current backend is not public. gollum-lib is the closest compatible implementation available. Some features of current Gollum, such as `__TOC__` and subdirectories, are not supported by GitHub Wiki.

We currently think we should improve the interchangeability of GitHub Wiki Markdown by implementing a conversion from GitHub Wiki Markdown to GFM with YAML front matter, which many static site generators can process.

gollum-lib provides no API for this conversion, and forcing it through its filter chain would hurt readability. We therefore think we should first create an independent Ruby module based on a copy of gollum-lib. Establishing such a module would also open the way to porting it to other languages.

## Build and Test Commands

- `bundle exec rake` — Install the dependencies. Run this only on first setup, or when the Gemfile or other dependency files have changed.
- `bundle exec rake check` — Run the linter and type checks.
- `bundle exec rake test` — Run the tests.
- `bundle exec rake build` — Build the site.

The standard verification sequence is `bundle exec rake check && bundle exec rake test && bundle exec rake build`.

## How to Judge Behaviour

In order of precedence:

1. Behaviour empirically verified on the real GitHub Wiki
2. The gollum-lib source code
3. General Markdown practice, only where the above do not decide the question

- Wiki editors are an uncontrolled general public whose syntax cannot be controlled, so all realistic and reasonable syntax must basically be supported.
- A test wiki is only a test corpus. Never use the presence or absence of a construct in it as grounds for scope or severity.
- Do not lower the ambition of the work on grounds of manpower or cost.

## Working Principles

- Never parse HTML with regular expressions. Use a parser.
- For Markdown-to-Markdown conversion, verify the meaning after the output is re-parsed downstream, not just the output string itself.
- Do not ignore or dismiss a point merely because a review classified it as a matter of design judgment. Raise it as a design problem and consult Yuuki. Design is an important part of this project.
- Verify claims by actually running the code, and cite the source of each conclusion. If a review was only a static reading, say so plainly.
- If an answer contained an error, do not focus on apologies or retractions: reconstruct and re-output the correct answer.
- Do not update generated files, such as those under `docs/`. Keep diffs concise.
- Commit and push only when Yuuki explicitly instructs it. Until then, leave changes uncommitted in the working tree, so that everything lands in a single commit when instructed.
- Reports and consultation with Yuuki are in Japanese.
