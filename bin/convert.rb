#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'fileutils'
require 'optparse'
require 'json'

# Path to the wiki repository.
WIKI_PATH = '../yuukinder.wiki'

# Pages not generated.
UNGENERATED_PAGES = Set['Home', 'README', 'LICENSE', 'META', '_Footer'].freeze

# Pages not listed on the home page.
UNLISTED_PAGES = Set['Wikinder', 'Wikinder-Japan'].freeze

# Output directory for the generated markdown.
MD_DIR = '../md'

# Site metadata (name, wiki URL, languages), maintained by hand.
SITE_PATH = '../site.json'

# Translated pages, supplied as data (one directory per language).
TRANSLATIONS_DIR = '../translations'

# Previous wiki HEAD used for incremental META.md sync.
CACHE_PATH = '../.cache/head'

# Parse the flag: build metadata from git history, ignoring META.md.
options = { ignore_meta: false }
OptionParser.new do |opts|
  opts.on('--ignore-meta', 'Ignore committed META.md and derive metadata from git history') do
    options[:ignore_meta] = true
  end
end.parse!

Dir.chdir(__dir__) do
  # Site metadata is read here. The converter receives the values,
  # never the file.
  site = File.exist?(SITE_PATH) ? JSON.parse(File.read(SITE_PATH)) : {}

  # Read the previous HEAD for incremental META.md sync.
  prev_head = nil
  if File.exist?(CACHE_PATH)
    candidate = File.read(CACHE_PATH).strip
    prev_head = candidate.match?(/\A[0-9a-f]{40}\z/) ? candidate : nil
  end

  wiki = Wikinder::GitHub::Wiki.new(
    WIKI_PATH,
    {
      ungenerated_pages: UNGENERATED_PAGES,
      unlisted_pages: UNLISTED_PAGES,
      ignore_meta: options[:ignore_meta],
      prev_head: prev_head,
      site_language: site['language'],
      supported_languages: site['languages'],
      translations_dir: TRANSLATIONS_DIR
    }
  )

  # Build, and record the wiki's current HEAD. The next build
  # reads it back as prev_head for the incremental META.md sync.
  wiki.build(MD_DIR)
  FileUtils.mkdir_p(File.dirname(CACHE_PATH))
  File.write(CACHE_PATH, "#{wiki.head}\n")
end
