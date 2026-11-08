# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'gollum-lib'
require 'nokogiri'
require 'uri'
require 'whatlanguage'

# CommonMarker options for rendering wiki markdown.
COMMONMARKER_OPTIONS = {
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
}.freeze #: commonmarker_options

# @type var render_markdown: ^(String) -> String
# Renders wiki markdown with CommonMarker options.
render_markdown = proc do |markdown|
  Commonmarker.to_html(markdown, options: COMMONMARKER_OPTIONS)
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
      META_HEADERS = [
        'Title', 'Author', 'Creation date', 'Modified date', 'Language', 'Aliases'
      ].freeze #: Array[String]

      # Precomputed header and separator rows for the META table.
      META_TABLE_HEADER = [
        "| #{META_HEADERS.join(' | ')} |",
        "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"
      ].freeze #: Array[String]

      # Separator between aliases in a META cell.
      ALIAS_SEPARATOR = '<br>' #: String

      # Pages not generated.
      UNGENERATED_PAGES = Set['Home', 'README', 'LICENSE', 'META'].freeze #: Set[String]

      # Pages not listed on the home page.
      UNLISTED_PAGES = Set['Wikinder', 'Wikinder-Japan'].freeze #: Set[String]

      # Gollum wiki configuration options.
      GOLLUM_OPTIONS = {
        allow_editing: false,
        filter_chain: %i[Tags TOC Render],
        hyphened_tag_lookup: true,
        universal_toc: true
      }.freeze #: gollum_wiki_options

      # @rbs @wiki: Gollum::Wiki
      # @rbs @url_base: URI::Generic
      # @rbs @prev_head: String?
      # @rbs @head_sha: String
      # @rbs @wiki_path: Pathname
      # @rbs @meta_path: Pathname
      # @rbs @meta_rows: Hash[String, meta_row]

      # Creates a new GitHub Wiki instance.
      #
      # @param path [String] Path to the wiki repository.
      # @param url_base [URI] Base URL for page links.
      # @param prev_head [String, nil] Previous head SHA for incremental update.
      # Loads META rows and resolves the current head at start.
      #: (String, url_base: URI::Generic, ?prev_head: String?) -> void
      def initialize(path, url_base:, prev_head: nil)
        @wiki_path = Pathname(path).expand_path
        @wiki = Gollum::Wiki.new(@wiki_path.to_s, GOLLUM_OPTIONS)
        @url_base = url_base
        @prev_head = prev_head
        @head_sha = @wiki.repo.head.commit.id
        @meta_path = @wiki_path.join('META.md')
        @meta_rows = parse_meta
      end

      # Returns data for every generated page.
      # Syncs META first so each page reads stable authorship.
      #: () -> Array[page_entry | redirect_entry]
      def pages_data
        pages = @wiki.pages
                     .select { |page| page.format == :markdown && !UNGENERATED_PAGES.include?(page.filename_stripped) }
        sync_meta(pages)

        pages.map { page_data(it) } + redirect_entries(pages)
      end

      # Returns site-wide data.
      # Exposes head so the next run can update incrementally.
      #: () -> { name: String, home: String, footer: String, head: String, language: String }
      def site_data
        home = @wiki.page('Home') or raise 'Home page is missing'
        footer = home.footer or raise 'Footer page is missing'

        {
          name: 'Wikinder',
          home: postprocess_html(home.formatted_data),
          footer: footer.formatted_data,
          head: @head_sha,
          language: detect_language(home.text_data)
        }
      end

      private

      # Returns the data for a single page.
      # Reads authorship from META rather than recomputing from history.
      #: (Gollum::Page) -> page_entry
      def page_data(page)
        slug = page.filename_stripped
        meta = @meta_rows.fetch(slug)

        {
          title: slug_to_title(slug),
          slug:,
          html: postprocess_html(page.formatted_data),
          toc: page.toc_data,
          **meta,
          wiki_url: URI("#{@url_base}/#{URI.encode_uri_component(slug)}"),
          listed: !UNLISTED_PAGES.include?(slug)
        } # : page_entry
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
      #: (URI::Generic) -> String
      def slug_from_href(href)
        path = URI.decode_uri_component(href.path.to_s)
        Pathname(path).sub_ext('').to_s.delete_prefix('/')
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

      # Returns aliases inside a table cell.
      # Treats break tags as separators between aliases.
      #: (Nokogiri::XML::Node) -> Array[String]
      def aliases_from_cell(cell)
        cell.children
            .slice_after { it.name == 'br' }
            .map { |group| group.select(&:text?).map(&:text).join.strip }
            .reject(&:empty?)
      end

      # Parses the META table into rows keyed by slug.
      # Reads the committed page through Gollum.
      #: () -> Hash[String, meta_row]
      def parse_meta
        page = @wiki.page('META') or return {}

        dom = Nokogiri::HTML5.fragment(page.formatted_data)
        dom.css('tbody tr').to_h do |row|
          title_cell, author_cell, creation_cell, modified_cell, language_cell, aliases_cell = row.css('td')
          link = title_cell.at_css('a')
          slug = slug_from_href(URI(link['href']))

          [
            slug,
            {
              author: author_cell.text.strip,
              creation_date: creation_cell.text.strip,
              modified_date: modified_cell.text.strip,
              language: language_cell.text.strip,
              aliases: aliases_from_cell(aliases_cell)
            }
          ]
        end
      end

      # Returns paths changed between previous head and head.
      # Compares blob SHAs from both tree listings.
      #: () -> Array[String]?
      def changed_paths
        prev_head = @prev_head or return
        return [] if prev_head == @head_sha

        prev_map = blob_sha_map(prev_head)
        head_map = blob_sha_map(@head_sha)
        (prev_map.keys | head_map.keys).reject { prev_map[it] == head_map[it] }
      end

      # Returns blob SHAs keyed by path for a ref.
      # Works for the incremental comparison.
      #: (String) -> Hash[String, String]
      def blob_sha_map(ref) = @wiki.tree_map_for(ref).to_h { [it.path, it.sha] }

      # Detects language from text.
      # Returns an ISO code for new META rows.
      #: (String?) -> String
      def detect_language(text) = WhatLanguage.language_iso(text)&.to_s || 'en'

      # Syncs META rows with current pages and writes the file.
      # Drops deleted pages and adds new pages with history heuristics.
      #: (Array[Gollum::Page]) -> void
      def sync_meta(pages)
        current_slugs = pages.to_set(&:filename_stripped)
        @meta_rows.select! { |slug, _row| current_slugs.include?(slug) }

        changed = changed_paths&.to_set

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
      #: (Gollum::Page) -> meta_row
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
      def latest_modified_date(page) = page.versions(limit: 1, follow: true).first.authored_date.utc.iso8601

      # Returns redirect entries mixed with pages.
      # Each entry holds its slug and display title.
      #: (Array[Gollum::Page]) -> Array[redirect_entry]
      def redirect_entries(pages)
        used = pages.to_set { it.filename_stripped.downcase }

        pages.flat_map do |page|
          target_slug = page.filename_stripped
          @meta_rows.fetch(target_slug)[:aliases].filter_map do |title|
            slug = title.tr(' ', '-')
            next if slug.empty? || !used.add?(slug.downcase)

            { slug:, title:, redirect: true, target_slug: }
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

        rows = sorted.map do |slug, row|
          title = slug_to_title(slug)
          aliases_str = row[:aliases].join(ALIAS_SEPARATOR)
          cells = ["[[#{title}]]", row[:author], row[:creation_date], row[:modified_date], row[:language], aliases_str]
          "| #{cells.join(' | ')} |"
        end

        content = [*META_TABLE_HEADER, *rows].join("\n") << "\n"
        @meta_path.write(content) unless @meta_path.exist? && @meta_path.read == content
      end
    end
  end
end
