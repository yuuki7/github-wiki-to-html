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
      ALIAS_SEPARATOR = '<br>' #: String

      # Pages not generated.
      UNGENERATED_PAGES = Set['Home', 'README', 'LICENSE', 'META'].freeze #: Set[String]

      # Pages not listed on the home page.
      UNLISTED_PAGES = Set['Wikinder', 'Wikinder-Japan'].freeze #: Set[String]

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
        @head_sha = @wiki.repo.head.commit.id
        @meta_path = File.join(@wiki_path, 'META.md')
        @meta_rows = parse_meta
      end

      # Returns data for every generated page.
      # Syncs META first so each page reads stable authorship.
      #: () -> Array[{ title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, language: String, aliases: Array[String], wiki_url: String, listed: bool } | { slug: String, title: String, redirect: bool, target_slug: String }]
      def pages_data
        pages = @wiki.pages
                     .select { |page| page.format == :markdown && !UNGENERATED_PAGES.include?(page.filename_stripped) }
        sync_meta(pages)

        pages.map { |page| page_data(page) } + redirect_entries(pages)
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
          head: @head_sha,
          language: detect_language(home.text_data)
        }
      end

      private

      # Returns the data for a single page.
      # Reads authorship from META rather than recomputing from history.
      #: (Gollum::Page) -> { title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, language: String, aliases: Array[String], wiki_url: String, listed: bool }
      def page_data(page)
        slug = page.filename_stripped
        meta = @meta_rows.fetch(slug)

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
          listed: !UNLISTED_PAGES.include?(slug)
        }
      end

      # Returns a display title from a slug.
      # Turns ASCII hyphens into spaces.
      #: (String) -> String
      def slug_to_title(slug) = slug.tr('-', ' ')

      # Strips the extension and rewrites encoded spaces to hyphens.
      # Keeps page URLs stable across wiki and site encodings.
      #: (String) -> String
      def normalize_link_path(path) = Pathname(path).sub_ext('').to_s.gsub('%20', '-')

      # Returns slug from a wiki link href.
      # Drops leading slash and extension after decoding.
      #: (String) -> String
      def slug_from_href(href)
        path = URI::DEFAULT_PARSER.unescape(URI(href).path)
        Pathname(path).sub_ext('').to_s.delete_prefix('/')
      end

      # Corrects internal links to match page URLs.
      # Rewrites wiki internal links under the site base.
      #: (String) -> String
      def postprocess_html(html)
        dom = Nokogiri::HTML5.fragment(html)
        dom.css('a.internal').each do |anchor|
          uri = URI(anchor['href'])
          uri.path = normalize_link_path(uri.path)
          anchor['href'] = uri.to_s
        end
        dom.to_html
      end

      # Returns aliases inside a table cell.
      # Treats break tags as separators between aliases.
      #: (Nokogiri::XML::Node) -> Array[String]
      def aliases_from_cell(cell)
        cell.children
            .slice_after { |node| node.name == 'br' }
            .map { |group| group.select(&:text?).map(&:text).join.strip }
            .reject(&:empty?)
      end

      # Parses the META table into rows keyed by slug.
      # Reads the committed page through Gollum.
      #: () -> Hash[String, { author: String, creation_date: String, modified_date: String, language: String, aliases: Array[String] }]
      def parse_meta
        page = @wiki.page('META') or return {}

        dom = Nokogiri::HTML5.fragment(page.formatted_data)
        rows = {}
        dom.css('tbody tr').each do |row|
          title_cell, author_cell, creation_cell, modified_cell, language_cell, aliases_cell = row.css('td')

          link = title_cell.css('a').first

          slug = slug_from_href(link['href'])

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
        return unless @prev_head
        return [] if @prev_head == @head_sha

        prev_map = blob_sha_map(@prev_head)
        head_map = blob_sha_map(@head_sha)
        (prev_map.keys | head_map.keys).reject { |path| prev_map[path] == head_map[path] }
      end

      # Returns blob SHAs keyed by path for a ref.
      # Works for the incremental comparison.
      #: (String) -> Hash[String, String]
      def blob_sha_map(ref)
        @wiki.tree_map_for(ref).to_h { |entry| [entry.path, entry.sha] }
      end

      # Detects language from text.
      # Returns an ISO code for new META rows.
      #: (String?) -> String
      def detect_language(text)
        WhatLanguage.language_iso(text)&.to_s || 'en'
      end

      # Syncs META rows with current pages and writes the file.
      # Drops deleted pages and adds new pages with history heuristics.
      #: (Array[Gollum::Page]) -> void
      def sync_meta(pages)
        current_slugs = pages.map(&:filename_stripped).to_set
        @meta_rows.select! { |slug, _row| current_slugs.include?(slug) }

        changed = changed_paths

        pages.each do |page|
          slug = page.filename_stripped
          if (row = @meta_rows[slug])
            row[:modified_date] = latest_modified_date(page) if changed.nil? || changed.include?(page.path)
          else
            @meta_rows[slug] = build_meta_row(page)
          end
        end

        write_meta
      end

      # Builds a new META row from Git history and content.
      # Extracts initial author/creation dates from the oldest commit and current modified date from the newest.
      #: (Gollum::Page) -> { author: String, creation_date: String, modified_date: String, language: String, aliases: Array[String] }
      def build_meta_row(page)
        versions = page.versions(limit: 0, follow: true)
        {
          author: versions.last.author.name,
          creation_date: versions.last.authored_date.utc.iso8601,
          modified_date: versions.first.authored_date.utc.iso8601,
          language: detect_language(page.text_data),
          aliases: []
        }
      end

      # Returns the latest author date in ISO 8601 for a page.
      #: (Gollum::Page) -> String
      def latest_modified_date(page)
        page.versions(limit: 1, follow: true).first.authored_date.utc.iso8601
      end

      # Returns redirect entries mixed with pages.
      # Each entry holds its slug and display title.
      #: (Array[Gollum::Page]) -> Array[{ slug: String, title: String, redirect: bool, target_slug: String }]
      def redirect_entries(pages)
        used = pages.map { |page| page.filename_stripped.downcase }.to_set

        pages.flat_map do |page|
          target_slug = page.filename_stripped
          @meta_rows.fetch(target_slug)[:aliases].filter_map do |title|
            slug = title.tr(' ', '-')
            next if slug.empty? || !used.add?(slug.downcase)

            { slug: slug, title: title, redirect: true, target_slug: target_slug }
          end
        end
      end

      # Writes META rows sorted by creation date.
      # Newest articles stay at the top for editors.
      #: () -> void
      def write_meta
        sorted = @meta_rows.sort do |(slug_a, row_a), (slug_b, row_b)|
          (row_b[:creation_date] <=> row_a[:creation_date]).nonzero? || (slug_a <=> slug_b)
        end

        lines = ["| #{META_HEADERS.join(' | ')} |", "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"]
        sorted.each do |slug, row|
          title = slug_to_title(slug)
          aliases_str = row[:aliases].join(ALIAS_SEPARATOR)
          cells = ["[[#{title}]]", row[:author], row[:creation_date], row[:modified_date], row[:language], aliases_str]
          lines << "| #{cells.join(' | ')} |"
        end

        content = "#{lines.join("\n")}\n"
        File.write(@meta_path, content) unless File.exist?(@meta_path) && File.read(@meta_path) == content
      end
    end
  end
end
