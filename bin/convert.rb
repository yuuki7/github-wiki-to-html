#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/github_wiki_to_html'

Dir.chdir(__dir__) do
  converter = GitHubWikiToHTML.new('../yuukinder.wiki')
  File.write('../astro/all-pages.json', converter.to_json + "\n")
end
