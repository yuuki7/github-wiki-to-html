#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'optparse'
require 'fileutils'
require 'json'

# Path to the wiki repository.
WIKI_PATH = '../../yuukinder.wiki'

# Pages not generated.
UNGENERATED_PAGES = Set['Home', 'README', 'LICENSE', 'META', '_Footer'].freeze

# Pages not listed on the home page.
UNLISTED_PAGES = Set['Wikinder', 'Wikinder-Japan'].freeze

# Site-wide name and wiki URL.
SITE_NAME = 'Wikinder'
WIKI_URL = 'https://github.com/yuuki7/yuukinder/wiki'

# Output directory for the generated markdown.
MD_DIR = '../md'

# Previous wiki head, used for an incremental META sync.
CACHE_PATH = '../.cache/head'

# Parse the flag that forces rebuilding META from scratch.
options = { ignore_meta: false }
OptionParser.new do |opts|
  opts.on('--ignore-meta', 'Ignore committed META and recreate it') do
    options[:ignore_meta] = true
  end
end.parse!

Dir.chdir(__dir__) do
  FileUtils.mkdir_p(File.dirname(CACHE_PATH))

  # Read the previous run's head for an incremental update.
  prev_head = nil
  if File.exist?(CACHE_PATH)
    candidate = File.read(CACHE_PATH).strip
    prev_head = candidate.match?(/\A[0-9a-f]{40}\z/) ? candidate : nil
  end

  wiki = Wikinder::GitHub::Wiki.new(
    WIKI_PATH,
    {
      prev_head:,
      ignore_meta: options[:ignore_meta],
      ungenerated_pages: UNGENERATED_PAGES,
      unlisted_pages: UNLISTED_PAGES
    }
  )
  wiki.build(MD_DIR)
  File.write(CACHE_PATH, "#{wiki.head}\n")
  File.write('../site.json', "#{JSON.pretty_generate({ name: SITE_NAME, wiki_url: WIKI_URL })}\n")
end
