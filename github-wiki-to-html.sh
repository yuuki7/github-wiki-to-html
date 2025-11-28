#!/bin/bash
##
# Wrapper for the main Ruby script, intended to be run directly from the terminal.
#

# Exit on error
set -e

ruby ./github-wiki-to-html.rb
find . -name '*.html' -not -name '404.html' -type f -print0 | xargs -0 html-beautify --replace --quiet
find . -name '*.xml' -type f -print0 | xargs -0 html-beautify --replace --quiet
