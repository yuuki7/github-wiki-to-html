#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'json'

Dir.chdir(__dir__) do
  prev_head = nil
  if File.exist?('../site.json')
    begin
      prev_head = JSON.parse(File.read('../site.json'))['head']
      prev_head = nil if prev_head.nil? || prev_head.to_s.strip.empty?
    rescue JSON::ParserError
      prev_head = nil
    end
  end

  wiki = Wikinder::GitHub::Wiki.new(
    '../../yuukinder.wiki',
    url_base: 'https://github.com/yuuki7/yuukinder/wiki',
    prev_head: prev_head
  )
  File.write('../all-pages.json', "#{JSON.pretty_generate(wiki.pages_data)}\n")
  File.write('../site.json', "#{JSON.pretty_generate(wiki.site_data)}\n")
end
