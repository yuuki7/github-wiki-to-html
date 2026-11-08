#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'json'
require 'optparse'

# Path to the wiki repository.
WIKI_PATH = '../../yuukinder.wiki'

# Base URL for page links.
WIKI_URL = 'https://github.com/yuuki7/yuukinder/wiki'

# Path to the site data file.
SITE_DATA_PATH = '../site.json'

# Path to the pages data file.
PAGES_DATA_PATH = '../all-pages.json'

options = { ignore_meta: false }
OptionParser.new do |opts|
  opts.on('--ignore-meta', 'Ignore committed META and recreate it') do
    options[:ignore_meta] = true
  end
end.parse!

Dir.chdir(__dir__) do
  prev_head = nil
  if File.exist?(SITE_DATA_PATH)
    begin
      prev_head = JSON.parse(File.read(SITE_DATA_PATH))['head']
      prev_head = nil if prev_head.nil? || prev_head.to_s.strip.empty?
    rescue JSON::ParserError
      prev_head = nil
    end
  end

  wiki = Wikinder::GitHub::Wiki.new(
    WIKI_PATH,
    {
      wiki_url: WIKI_URL,
      prev_head:,
      ignore_meta: options[:ignore_meta]
    }
  )
  File.write(PAGES_DATA_PATH, "#{JSON.pretty_generate(wiki.pages_data)}\n")
  File.write(SITE_DATA_PATH, "#{JSON.pretty_generate(wiki.site_data)}\n")
end
