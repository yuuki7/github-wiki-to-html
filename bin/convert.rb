#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'

require 'json'

Dir.chdir(__dir__) do
  wiki = Wikinder::GitHub::Wiki.new('../../yuukinder.wiki')
  json = JSON.pretty_generate(wiki)
  File.write('../all-pages.json', "#{json}\n")
end
