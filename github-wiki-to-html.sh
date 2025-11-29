#!/bin/bash
##
# Wrapper for the main Ruby script. Run directly from the terminal.
#

# Exit immediately if any command fails.
set -e

# Run the main Ruby script.
ruby github-wiki-to-html.rb

# Beautify the generated HTML/XML files.
find . \
  \( -name '*.html' -o -name '*.xml' \) \
  \! -name '404.html' \
  -type f -print0 \
  | xargs -0 npx html-beautify --quiet --replace
