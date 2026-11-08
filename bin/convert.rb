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
SITE_PATH = '../site.json'

# Path to the pages data file.
PAGES_PATH = '../all-pages.json'

options = { ignore_meta: false }
OptionParser.new do |opts|
  opts.on('--ignore-meta', 'Ignore committed META and recreate it') do
    options[:ignore_meta] = true
  end
end.parse!

Dir.chdir(__dir__) do
  prev_head_id = nil
  if File.exist?(SITE_PATH)
    begin
      prev_head_id = JSON.parse(File.read(SITE_PATH))['head_id']
      prev_head_id = nil if prev_head_id.nil? || prev_head_id.to_s.strip.empty?
    rescue JSON::ParserError
      prev_head_id = nil
    end
  end

  wiki = Wikinder::GitHub::Wiki.new(
    WIKI_PATH,
    {
      wiki_url: WIKI_URL,
      prev_head_id:,
      ignore_meta: options[:ignore_meta]
    }
  )
  File.write(PAGES_PATH, "#{JSON.pretty_generate(wiki.pages_data)}\n")
  File.write(SITE_PATH, "#{JSON.pretty_generate(wiki.site_data)}\n")
end
