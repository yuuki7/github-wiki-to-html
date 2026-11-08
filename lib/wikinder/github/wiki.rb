# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'gollum-lib'
require 'nokogiri'
require 'pathname'
require 'uri'
require 'whatlanguage'

# @type var render_markdown: ^(String) -> String
# Renders wiki markdown with CommonMarker options.
render_markdown = proc do |markdown|
  Commonmarker.to_html(
    markdown,
    options: {
      render: {
        unsafe: true
      },
      extension: {
        autolink: true,
        footnotes: true,
        math_code: true,
        math_dollars: true,
        strikethrough: true,
        table: true,
        tagfilter: false,
        tasklist: true
      }
    }
  )
end

# Makes CommonMarker the only renderer for Gollum.
# Replaces defaults so wiki and rendered HTML stay consistent.
GitHub::Markup::Markdown::MARKDOWN_GEMS.replace('commonmarker' => render_markdown)

module Wikinder
  module GitHub
    # Represents a GitHub Wiki.
    # Loads pages with Gollum and serves META as the source for authorship.
    class Wiki
      # Column labels for the META table.
      META_HEADERS = ['Title', 'Author', 'Creation date', 'Modified date', 'Language', 'Aliases'].freeze #: Array[String]

      # Separator between aliases in a META cell.
      ALIAS_SEPARATOR = '<br>'.freeze #: String

      # Pages not generated.
      UNGENERATED_PAGE_SLUGS = %w[Home README LICENSE META].freeze #: Array[String]

      # Pages not listed on the home page.
      UNLISTED_PAGE_SLUGS = %w[Wikinder Wikinder-Japan].freeze #: Array[String]

      # @rbs @wiki: Gollum::Wiki
      # @rbs @url_base: String
      # @rbs @prev_head: String?
      # @rbs @head_sha: String
      # @rbs @wiki_path: String
      # @rbs @meta_path: String
      # @rbs @meta_rows: Hash[String, { author: String, creation_date: String, modified_date: String, language: String, aliases: Array[String] }]

      # Creates a new GitHub Wiki instance.
      #
      # @param path [String] Path to the wiki repository.
      # @param url_base [String] Base URL for page links.
      # @param prev_head [String, nil] Previous head SHA for incremental update.
      # Loads META rows and resolves the current head at start.
      #: (String, url_base: String, ?prev_head: String?) -> void
      def initialize(path, url_base:, prev_head: nil)
        @wiki_path = File.expand_path(path)
        @wiki = Gollum::Wiki.new(
          @wiki_path,
          {
            allow_editing: false,
            filter_chain: %i[Tags TOC Render],
            hyphened_tag_lookup: true,
            universal_toc: true
          }
        )
        @url_base = url_base
        @prev_head = prev_head
        @head_sha = current_head_sha
        @meta_path = File.join(@wiki_path, 'META.md')
        @meta_rows = parse_meta
      end

      # Returns data for every generated page.
      # Syncs META first so each page reads stable authorship.
      #: () -> Array[{ title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, language: String, aliases: Array[String], wiki_url: String, listed: bool } | { slug: String, title: String, redirect: bool, target_slug: String }]
      def pages_data
        pages = @wiki.pages
                     .select { |page| page.format == :markdown }
                     .reject { |page| UNGENERATED_PAGE_SLUGS.include?(page.filename_stripped) }
        sync_meta(pages)
        canonical = pages.map { |page| page_data(page) }
        canonical + redirect_entries(pages)
      end

      # Returns site-wide data.
      # Exposes head so the next run can update incrementally.
      #: () -> { name: String, home: String, footer: String, head: String, language: String }
      def site_data
        home = @wiki.page('Home')
        {
          name: 'Wikinder',
          home: postprocess_html(home.formatted_data),
          footer: home.footer.formatted_data,
          head: @head_sha.to_s,
          language: detect_language(home.text_data)
        }
      end

      private

      # Returns the data for a single page.
      # Reads authorship from META rather than recomputing from history.
      #: (Gollum::Page) -> { title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, language: String, aliases: Array[String], wiki_url: String, listed: bool }
      def page_data(page)
        slug = page.filename_stripped
        meta = @meta_rows[slug]

        {
          title: slug_to_title(slug),
          slug: slug,
          html: postprocess_html(page.formatted_data),
          toc: page.toc_data,
          creation_date: meta[:creation_date],
          modified_date: meta[:modified_date],
          author: meta[:author],
          language: meta[:language],
          aliases: meta[:aliases],
          wiki_url: "#{@url_base}/#{URI::DEFAULT_PARSER.escape(slug)}",
          listed: !UNLISTED_PAGE_SLUGS.include?(slug)
        }
      end

      # Returns a display title from a slug.
      # Turns ASCII hyphens into spaces.
      #: (String) -> String
      def slug_to_title(slug)
        slug.tr('-', ' ')
      end

      # Returns a path without its extension.
      # Used when resolving wiki and site URLs.
      #: (String) -> String
      def strip_extension(path)
        Pathname(path).sub_ext('').to_s
      end

      # Corrects internal links to match page URLs.
      # Rewrites wiki internal links under the site base.
      #: (String) -> String
      def postprocess_html(html)
        dom = Nokogiri::HTML5.fragment(html)
        dom.css('a.internal').each do |anchor|
          uri = URI(anchor['href'])
          uri.path = normalize_link_path(uri.path.to_s)
          anchor['href'] = uri.to_s
        end
        dom.to_html
      end

      # Strips the extension and rewrites encoded spaces to hyphens.
      # Keeps page URLs stable across wiki and site encodings.
      #: (String) -> String
      def normalize_link_path(path)
        strip_extension(path).gsub('%20', '-')
      end

      # Returns the current head SHA.
      # HEAD defines the wiki snapshot for this build.
      #: () -> String
      def current_head_sha
        @wiki.repo.head.commit.id
      end

      # Returns slug from a wiki link href.
      # Drops leading slash and extension after decoding.
      #: (String) -> String
      def slug_from_href(href)
        path = URI::DEFAULT_PARSER.unescape(URI(href).path.to_s)
        strip_extension(path).sub(%r{\A/+}, '')
      end

      # Returns aliases inside a table cell.
      # Treats break tags as separators between aliases.
      #: (untyped) -> Array[String]
      def aliases_from_cell(cell)
        items = []
        current = +''
        cell.children.each do |child|
          if child.name == 'br'
            items << current.strip
            current = +''
          elsif child.text?
            current << child.text
          end
        end
        items << current.strip
        items.reject(&:empty?)
      end

      # Parses the META table into rows keyed by slug.
      # Reads the committed page through Gollum.
      #: () -> Hash[String, { author: String, creation_date: String, modified_date: String, language: String, aliases: Array[String] }]
      def parse_meta
        page = @wiki.page('META')
        return {} unless page

        dom = Nokogiri::HTML5.fragment(page.formatted_data)
        rows = {}
        dom.css('tbody tr').each do |row|
          cells = row.css('td')
          next if cells.size < META_HEADERS.size

          title_cell, author_cell, creation_cell, modified_cell, language_cell, aliases_cell = cells[0, META_HEADERS.size]

          link = title_cell.css('a').first
          next unless link

          slug = slug_from_href(link['href'].to_s)
          next if slug.empty?

          rows[slug] = {
            author: author_cell.text.strip,
            creation_date: creation_cell.text.strip,
            modified_date: modified_cell.text.strip,
            language: language_cell.text.strip,
            aliases: aliases_from_cell(aliases_cell)
          }
        end
        rows
      end

      # Returns paths changed between previous head and head.
      # Compares blob SHAs from both tree listings.
      #: () -> Array[String]?
      def changed_paths
        return nil if @prev_head.nil?
        return [] if @prev_head == @head_sha

        prev_commit = @wiki.commit_for(@prev_head)
        head_commit = @wiki.commit_for(@head_sha)
        return nil if prev_commit.nil? || head_commit.nil?

        prev_map = blob_sha_map(@prev_head)
        head_map = blob_sha_map(@head_sha)
        (head_map.keys + prev_map.keys).uniq.select { |path| prev_map[path] != head_map[path] }
      end

      # Returns blob SHAs keyed by path for a ref.
      # Works for the incremental comparison.
      #: (String) -> Hash[String, String]
      def blob_sha_map(ref)
        map = {}
        @wiki.tree_map_for(ref).each { |entry| map[entry.path] = entry.sha }
        map
      end

      # Detects language from text.
      # Returns an ISO code for new META rows.
      #: (String?) -> String
      def detect_language(text)
        return 'en' if text.nil? || text.empty?

        WhatLanguage.language_iso(text)&.to_s || 'en'
      end

      # Syncs META rows with current pages and writes the file.
      # Drops deleted pages and adds new pages with history heuristics.
      #: (Array[Gollum::Page]) -> void
      def sync_meta(pages)
        current = {}
        pages.each { |page| current[page.filename_stripped] = page }
        @meta_rows.select! { |slug, _row| current.key?(slug) }

        changed = changed_paths

        pages.each do |page|
          slug = page.filename_stripped
          row = @meta_rows[slug]

          if row.nil?
            versions = page.versions({ limit: 0, follow: true })
            oldest = versions.last
            newest = versions.first
            author = oldest.author.name
            creation = oldest.authored_date.utc.iso8601
            modified = newest.authored_date.utc.iso8601
            language = detect_language(page.text_data)
            @meta_rows[slug] = {
              author: author,
              creation_date: creation,
              modified_date: modified,
              language: language,
              aliases: []
            }
          elsif changed.nil? || changed.include?(page.path)
            newest = page.versions({ limit: 1, follow: true }).first
            row[:modified_date] = newest.authored_date.utc.iso8601
          end
        end

        write_meta
      end

      # Returns redirect entries mixed with pages.
      # Each entry holds its slug and display title.
      #: (Array[Gollum::Page]) -> Array[{ slug: String, title: String, redirect: bool, target_slug: String }]
      def redirect_entries(pages)
        used = {}
        pages.each { |page| used[page.filename_stripped.downcase] = true }
        items = []
        pages.each do |page|
          slug = page.filename_stripped
          row = @meta_rows[slug]
          row[:aliases].each do |alias_text|
            alias_slug = alias_text.gsub(' ', '-')
            next if alias_slug.empty? || used[alias_slug.downcase]

            used[alias_slug.downcase] = true
            items << { slug: alias_slug, title: alias_text, redirect: true, target_slug: slug }
          end
        end
        items
      end

      # Writes META rows sorted by creation date.
      # Newest articles stay at the top for editors.
      #: () -> void
      def write_meta
        sorted = @meta_rows.sort do |(slug_a, row_a), (slug_b, row_b)|
          cmp = row_b[:creation_date] <=> row_a[:creation_date]
          cmp.nil? || cmp.zero? ? (slug_a <=> slug_b) : cmp
        end

        lines = ["| #{META_HEADERS.join(' | ')} |", "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"]
        sorted.each do |slug, row|
          title = slug_to_title(slug)
          aliases_str = row[:aliases].join(ALIAS_SEPARATOR)
          cells = ["[[#{title}]]", row[:author], row[:creation_date], row[:modified_date], row[:language], aliases_str]
          lines << "| #{cells.join(' | ')} |"
        end

        content = "#{lines.join("\n")}\n"
        old = File.exist?(@meta_path) ? File.read(@meta_path) : ''
        File.write(@meta_path, content) if content != old
      end
    end
  end
end
