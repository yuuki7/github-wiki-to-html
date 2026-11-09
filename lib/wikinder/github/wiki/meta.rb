# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'nokogiri'
require 'pathname'
require 'uri'
require 'whatlanguage'

module Wikinder
  module GitHub
    class Wiki
      # Reads and writes the META page, syncing rows with git history.
      class Meta
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

        # Represents one row of the META table.
        class Row
          attr_accessor :author, :creation_date, :modified_date, :language, :aliases

          #: (author: String, creation_date: String, modified_date: String, language: String, aliases: Array[String]) -> void
          def initialize(author:, creation_date:, modified_date:, language:, aliases:)
            @author = author
            @creation_date = creation_date
            @modified_date = modified_date
            @language = language
            @aliases = aliases
          end

          #: () -> meta_row
          def to_h
            {
              author: @author,
              creation_date: @creation_date,
              modified_date: @modified_date,
              language: @language,
              aliases: @aliases
            }
          end
        end

        # @rbs @wiki: Gollum::Wiki
        # @rbs @meta_path: Pathname
        # @rbs @prev_head: String?
        # @rbs @head: String
        # @rbs @ignore_meta: bool?
        # @rbs @rows: Hash[String, Row]

        # Creates a new Meta instance.
        #
        # @param wiki [Gollum::Wiki] The wiki instance to read from.
        # @param meta_path [Pathname] Path to the META.md file.
        # @param head [String] Current head SHA.
        # @param prev_head [String?] Previous head SHA for incremental update.
        # @param ignore_meta [bool?] Ignore committed META and recreate it.
        #: (wiki: Gollum::Wiki, meta_path: Pathname, head: String, ?prev_head: String?, ?ignore_meta: bool) -> void
        def initialize(wiki:, meta_path:, head:, prev_head: nil, ignore_meta: false)
          @wiki = wiki
          @meta_path = meta_path
          @prev_head = prev_head
          @head = head
          @ignore_meta = ignore_meta
          @rows = parse
        end

        # Returns rows keyed by slug.
        #: () -> Hash[String, Row]
        attr_reader :rows

        # Syncs META rows with current pages and writes the file.
        # Drops deleted pages and adds new pages with history heuristics.
        #: (Array[Gollum::Page]) -> void
        def sync!(pages)
          current_slugs = pages.to_set(&:filename_stripped)
          @rows.select! { |slug, _row| current_slugs.include?(slug) }

          changed = changed_paths&.to_set

          pages.each do |page|
            slug = page.filename_stripped
            if (row = @rows[slug])
              if changed.nil? || changed.include?(page.path)
                row.modified_date = latest_modified_date(page)
                versions = page.versions({ limit: 0, follow: true })
                old_titles(versions, page.path).each do |title|
                  row.aliases << title unless row.aliases.include?(title)
                end
              end
            else
              @rows[slug] = build_row(page)
            end
          end

          write!
        end

        # Detects language from text.
        # Returns an ISO code for new META rows.
        #: (String?) -> String
        def detect_language(text) = WhatLanguage.language_iso(text)&.to_s || 'en'

        private

        # Parses the META table into rows keyed by slug.
        # Reads the committed page through Gollum.
        #: () -> Hash[String, Row]
        def parse
          return {} if @ignore_meta

          page = @wiki.page('META') or return {}

          dom = Nokogiri::HTML5.fragment(page.formatted_data)
          dom.css('tbody tr').to_h do |row|
            title_cell, author_cell, creation_cell, modified_cell, language_cell, aliases_cell = row.css('td')
            link = title_cell.at_css('a')
            slug = slug_from_href(URI(link['href']))

            [
              slug,
              Row.new(
                author: author_cell.text.strip,
                creation_date: creation_cell.text.strip,
                modified_date: modified_cell.text.strip,
                language: language_cell.text.strip,
                aliases: aliases_from_cell(aliases_cell)
              )
            ]
          end
        end

        # Returns paths changed between previous head and head.
        # Compares blob SHAs from both tree listings.
        #: () -> Array[String]?
        def changed_paths
          prev_head = @prev_head or return
          return [] if prev_head == @head

          prev_map = blob_sha_map(prev_head)
          head_map = blob_sha_map(@head)
          (prev_map.keys | head_map.keys).reject { prev_map[it] == head_map[it] }
        end

        # Returns blob SHAs keyed by path for a ref.
        # Works for the incremental comparison.
        #: (String) -> Hash[String, String]
        def blob_sha_map(ref) = @wiki.tree_map_for(ref).to_h { [it.path, it.sha] }

        # Builds a new META row from Git history and content.
        # Extracts initial author/creation dates from the oldest commit and current modified date from the newest.
        #: (Gollum::Page) -> Row
        def build_row(page)
          versions = page.versions(limit: 0, follow: true)
          Row.new(
            author: versions.last.author.name,
            creation_date: versions.last.authored_date.utc.iso8601,
            modified_date: versions.first.authored_date.utc.iso8601,
            language: detect_language(page.text_data),
            aliases: old_titles(versions, page.path)
          )
        end

        # Returns old titles found in rename history.
        #: (Array[Gollum::Version], String) -> Array[String]
        def old_titles(versions, current_path)
          paths = versions.map(&:tracked_pathname).compact.uniq - [current_path]
          paths.map { |tracked| slug_to_title(Pathname(tracked).sub_ext('').basename.to_s) }
        end

        # Returns the latest author date in ISO 8601 for a page.
        #: (Gollum::Page) -> String
        def latest_modified_date(page) = page.versions(limit: 1, follow: true).first.authored_date.utc.iso8601

        # Returns slug from a wiki link href.
        # Drops leading slash and extension after decoding.
        #: (URI::Generic) -> String
        def slug_from_href(href)
          path = URI.decode_uri_component(href.path.to_s)
          Pathname(path).sub_ext('').to_s.delete_prefix('/')
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

        # Returns a display title from a slug.
        # Turns ASCII hyphens into spaces.
        #: (String) -> String
        def slug_to_title(slug) = slug.tr('-', ' ')

        # Writes META rows sorted by creation date.
        # Newest articles stay at the top for editors.
        #: () -> void
        def write!
          sorted = @rows.sort do |(slug_a, row_a), (slug_b, row_b)|
            (row_b.creation_date <=> row_a.creation_date).nonzero? || (slug_a <=> slug_b)
          end
          rows = sorted.map do |slug, row|
            title = slug_to_title(slug)
            aliases_str = row.aliases.join(ALIAS_SEPARATOR)
            cells = ["[[#{title}]]", row.author, row.creation_date, row.modified_date, row.language, aliases_str]
            inner = cells.map { |cell| cell.empty? ? ' ' : " #{cell} " }.join('|')
            "|#{inner}|"
          end

          content = [*META_TABLE_HEADER, *rows].join("\n") << "\n"
          @meta_path.write(content) unless @meta_path.exist? && @meta_path.read == content
        end
      end
    end
  end
end
