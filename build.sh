#!/bin/bash
# Exit immediately if any command fails.
set -xeuo pipefail
IFS=$'\n\t'

bundle install && bundle update --all && npm install && npm update
bundle exec rubocop
bundle exec rbs-inline --output lib && bundle exec rbs validate
ruby bin/convert.rb
npm run build
npm run preview -- --background
