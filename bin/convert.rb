#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/wikinder/github/wiki'
require 'optparse'
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

# Parse the flag: build metadata from git history, ignoring META.md.
options = { ignore_meta: false }
OptionParser.new do |opts|
  opts.on('--ignore-meta', 'Ignore committed META.md and derive metadata from git history') do
    options[:ignore_meta] = true
  end
end.parse!

Dir.chdir(__dir__) do
  wiki = Wikinder::GitHub::Wiki.new(
    WIKI_PATH,
    {
      ungenerated_pages: UNGENERATED_PAGES,
      unlisted_pages: UNLISTED_PAGES,
      ignore_meta: options[:ignore_meta]
    }
  )
  wiki.build(MD_DIR)
  File.write('../site.json', "#{JSON.pretty_generate({ name: SITE_NAME, wiki_url: WIKI_URL })}\n")
end
