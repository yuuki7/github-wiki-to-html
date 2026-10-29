#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'json'

Dir.chdir(__dir__) do
  wiki = Wikinder::GitHub::Wiki.new('../../yuukinder.wiki')
  File.write('../all-pages.json', "#{JSON.pretty_generate(wiki.pages_data)}\n")
  File.write('../site.json', "#{JSON.pretty_generate(wiki.site_data)}\n")
end
