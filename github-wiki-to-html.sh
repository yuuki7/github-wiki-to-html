#!/bin/bash
##
# Wrapper for the main Ruby script. Run directly from the terminal.
#

# Stop execution if any command fails.
set -e

# Run the main Ruby script.
ruby github-wiki-to-html.rb

# Beautify the generated HTML/XML files using the `js-beautify` tool.
find wikinder.github.io \
  \( -name '*.html' -o -name '*.xml' \) \
  -not -name '404.html' \
  -type f -print0 \
  | xargs -0 html-beautify --replace --quiet
