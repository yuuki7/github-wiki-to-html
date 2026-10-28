#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'

require 'json'

Dir.chdir(__dir__) do
  wiki = Wikinder::GitHub::Wiki.new('../../yuukinder.wiki')
  all_pages = wiki.to_json

  # json = JSON.parse(all_pages).find { |page| page['slug'] == 'yuuki' }
  # puts json['md']
  # puts json['html']

  File.write('../all-pages.json', "#{all_pages}\n")
end
