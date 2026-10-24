#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/github_wiki_to_html'

require 'json'

Dir.chdir(__dir__) do
  wiki = GitHubWikiToHTML.new('../yuukinder.wiki')
  json = JSON.pretty_generate(wiki)
  File.write('../all-pages.json', "#{json}\n")
end
