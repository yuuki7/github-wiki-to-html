# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'commonmarker'
require 'nokogiri'
require 'uri'
require 'whatlanguage'

module Wikinder
  module GitHub
    class Wiki
      # Reads and writes the META page, syncing rows with git history.
      # rubocop:disable Metrics/ClassLength
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

        # @rbs @wiki: Gollum::Wiki
        # @rbs @meta_path: Pathname
        # @rbs @head: String
        # @rbs @prev_head: String?
        # @rbs @ignore_meta: bool?

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
          @head = head
          @prev_head = prev_head
          @ignore_meta = ignore_meta
          @rows = parse
        end

        # Returns rows keyed by slug.
        attr_reader :rows #: Hash[String, Row]

        # Syncs META rows with current pages and writes the file.
        # Drops deleted pages and adds new pages with history heuristics.
        #: (Array[Gollum::Page]) -> void
        def sync!(pages)
          @rows.select! { |slug, _| pages.to_set(&:filename_stripped).include?(slug) }
          changed = changed_paths&.to_set
          pages.each { |page| refresh_row(page, changed) }
          write!
        end

        # Detects language from text.
        # Returns an ISO code for new META rows.
        #: (String?) -> String
        def detect_language(text) = WhatLanguage.language_iso(text)&.to_s || 'en'

        private

        # Updates or creates one row for one page.
        # Skips unchanged rows when an incremental diff is available.
        #: (Gollum::Page, Set[String]?) -> void
        def refresh_row(page, changed)
          slug = page.filename_stripped
          row = @rows[slug]
          return refresh_incremental(row, page) if row && changed && !changed.include?(page.path)

          versions = page.versions({ limit: 0, follow: true })
          if row
            row.modified_date = versions.first.authored_date.utc.iso8601
            absorb_aliases(row, page.path, versions)
          else
            @rows[slug] = build_row(page, versions)
          end
        end

        # Applies the cheap part of a sync to an unchanged row.
        #: (Row, Gollum::Page) -> void
        def refresh_incremental(row, page)
          versions = page.versions({ limit: 1, follow: true })
          row.modified_date = versions.first.authored_date.utc.iso8601
        end

        # Appends aliases found in the page's rename history.
        #: (Row, String, Array[Gollum::Version]) -> void
        def absorb_aliases(row, path, versions)
          old_titles(versions, path).each do |title|
            row.aliases << title unless row.aliases.include?(title)
          end
        end

        # Returns paths changed between previous head and head.
        # Uses libgit2's tree diff, one pass over the diff only.
        #: () -> Array[String]?
        def changed_paths
          prev_head = @prev_head or return
          return [] if prev_head == @head

          diff_paths(prev_head, @head)
        end

        # Returns paths of files changed between two refs.
        # Uses libgit2's native tree diff, not hand-rolled blob maps.
        #: (String, String) -> Array[String]
        def diff_paths(prev_ref, head_ref)
          prev = @wiki.commit_for(prev_ref)
          head = @wiki.commit_for(head_ref)
          return [] if prev.nil? || head.nil?

          diff = prev.commit.diff(head.commit)
          diff.deltas.flat_map { |delta| [delta.old_file[:path], delta.new_file[:path]] }.uniq
        end

        # Parses the META table into rows keyed by slug.
        # Reads the committed page and walks its table AST.
        #: () -> Hash[String, Row]
        def parse
          return {} if @ignore_meta

          page = @wiki.page('META') or return {}
          parse_page(page)
        end

        # Builds one row from each data row of the META table.
        #: (Gollum::Page) -> Hash[String, Row]
        # Builds one row from each data row of the META table.
        # Renders Meta through Commonmarker and parses the resulting HTML
        # fragment with Nokogiri; header rows live in <thead>, rows here in <tbody>.
        #: (Gollum::Page) -> Hash[String, Row]
        def parse_page(page)
          html = Commonmarker.to_html(
            page.formatted_data,
            options: { extension: { table: true }, render: { unsafe: true } }
          )
          table = Nokogiri::HTML5.fragment(html).at_css('table')
          return {} unless table

          rows = {} #: Hash[String, Row]
          table.css('tbody tr').each do |tr|
            cells = tr.css('td')
            next if cells.size < 6

            href = cells[0].at_css('a')&.[]('href')
            next unless href

            slug = slug_from_href(href)
            attrs = {
              author: cell_text(cells[1]),
              creation_date: cell_text(cells[2]),
              modified_date: cell_text(cells[3]),
              language: cell_text(cells[4]),
              aliases: cell_aliases(cells[5])
            } #: meta_row
            rows[slug] = Row.new(attrs)
          end
          rows
        end

        # Returns the stripped text of a cell.
        #: (Nokogiri::XML::Element) -> String
        def cell_text(cell)
          cell.text.strip.gsub(/\s+/, ' ')
        end

        # Splits an aliases cell into its aliases at break tags.
        #: (Nokogiri::XML::Element) -> Array[String]
        def cell_aliases(cell)
          cell.children
              .slice_after { |child| child.name == 'br' }
              .map { |group| group.select(&:text?).map(&:text).join.strip }
              .reject(&:empty?)
        end

        # Builds a new META row from Git history and content.
        # Extracts initial author/creation dates from the oldest commit and current modified date from the newest.
        #: (Gollum::Page, Array[Gollum::Version]) -> Row
        def build_row(page, versions)
          Row.new(
            {
              author: versions.last.author.name,
              creation_date: versions.last.authored_date.utc.iso8601,
              modified_date: versions.first.authored_date.utc.iso8601,
              language: detect_language(page.text_data),
              aliases: old_titles(versions, page.path)
            }
          )
        end

        # Returns old titles found in rename history.
        #: (Array[Gollum::Version], String) -> Array[String]
        def old_titles(versions, current_path)
          paths = versions.map(&:tracked_pathname).compact.uniq - [current_path]
          paths.map { |tracked| Page.title(Pathname(tracked).sub_ext('').basename.to_s) }
        end

        # Returns slug from a wiki link href.
        # Drops leading slash and extension after decoding.
        #: (String) -> String
        def slug_from_href(href)
          path = URI.decode_uri_component(href)
          Pathname(path).sub_ext('').to_s.delete_prefix('/')
        rescue URI::InvalidURIError, URI::InvalidComponentError, ArgumentError
          Pathname(href).sub_ext('').to_s.delete_prefix('/')
        end

        # Writes META rows sorted by creation date.
        # Newest articles stay at the top for editors.
        #: () -> void
        def write!
          sorted = sort_rows
          content = [*META_TABLE_HEADER, *sorted.map { |row| render_row(row) }].join("\n") << "\n"
          @meta_path.write(content) unless @meta_path.exist? && @meta_path.read == content
        end

        # Returns rows sorted by creation date, newest first.
        #: () -> Array[[String, Row]]
        def sort_rows
          @rows.sort do |(a, ra), (b, rb)|
            (rb.creation_date <=> ra.creation_date).nonzero? || (a <=> b)
          end
        end

        # Renders one row into its markdown table line.
        #: ([String, Row]) -> String
        def render_row(pair)
          slug, row = pair
          cells = [
            "[[#{Page.title(slug)}]]", row.author, row.creation_date,
            row.modified_date, row.language, row.aliases.join(ALIAS_SEPARATOR)
          ]
          inner = cells.map { |cell| cell.empty? ? ' ' : " #{cell} " }.join('|')
          "|#{inner}|"
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
