# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'pathname'
require 'commonmarker'

module Wikinder
  module GitHub
    class Wiki
      # Reads and writes META.md, syncing article rows with git history.
      #
      # Existing rows are kept (author, creation date, aliases are curated
      # by hand), but modified_date and language are refreshed from git and
      # rows for missing or deleted pages are rebuilt from history.
      #
      # With ignore_meta set, every row is rebuilt from history and the
      # previously committed META.md is disregarded.
      module Meta
        META_HEADERS = ['Title', 'Author', 'Creation date', 'Modified date', 'Language', 'Aliases'].freeze #: Array[String]
        META_TABLE_HEADER = [
          "| #{META_HEADERS.join(' | ')} |",
          "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"
        ].freeze #: Array[String]
        ALIAS_SEPARATOR = '<br>' #: String

        #: (Pathname, ?ignore_meta: bool) -> Hash[String, Hash[Symbol, untyped]]
        def self.load(meta_path, ignore_meta: false)
          return {} if ignore_meta
          return {} unless meta_path.exist?

          result = {} #: Hash[String, Hash[Symbol, untyped]]
          meta_path.each_line do |line|
            row = parse_row(line.chomp)
            result[row[:slug]] = row if row
          end
          result
        end

        #: (String) -> Hash[Symbol, untyped]?
        def self.parse_row(line)
          return nil unless line.start_with?('|') && line.end_with?('|')

          cells = Array(line.split('|', -1)[1..-2]).map(&:strip)
          return nil if cells.length < META_HEADERS.length
          return nil if cells[0].start_with?('---')
          return nil if cells[0] == 'Title'

          match = cells[0].match(/\[\[([^\]]+)\]\]/)
          return nil unless match

          title = match[1].strip
          slug = Slugs.for_title(title)
          {
            slug: slug,
            title: title,
            author: cells[1],
            creation_date: cells[2],
            modified_date: cells[3],
            language: cells[4],
            aliases: cells[5].split(ALIAS_SEPARATOR).map(&:strip).reject(&:empty?)
          }
        end

        # Syncs META.md with the given pages and returns the merged rows,
        # keyed by slug.
        #: (Wiki, Array[String], Pathname, ?ignore_meta: bool) -> Hash[String, Hash[Symbol, untyped]]
        def self.sync!(wiki, pages, meta_path, ignore_meta: false)
          previously = load(meta_path, ignore_meta: ignore_meta)
          rows = {} #: Hash[String, Hash[Symbol, untyped]]

          pages.each do |page|
            slug = File.basename(page, '.md')
            bounds = wiki.commit_bounds_for(page)
            last = bounds[:latest]
            first = bounds[:earliest]
            renames = wiki.rename_history_for(page)
            rename_slugs = renames.map { |p| File.basename(p, '.md') }
            row = previously[slug] || rename_slugs.lazy.map { |s| previously[s] }.compact.first
            if row
              # Keep curated fields; refresh what git knows.
              row = row.dup
              row[:slug] = slug
              row[:title] = Slugs.title_for(slug)
              row[:modified_date] = last.time.utc.iso8601 if last
              aliases = rename_slugs.map { |s| Slugs.title_for(s) }
              row[:aliases] = merge_aliases(row[:aliases], aliases)
            else
              row = {
                slug: slug,
                title: Slugs.title_for(slug),
                author: last&.author&.[](:name) || 'unknown',
                creation_date: first&.time&.utc&.iso8601 || 'unknown',
                modified_date: last&.time&.utc&.iso8601 || 'unknown',
                language: Language.call(wiki.text_for(page)),
                aliases: rename_slugs.map { |s| Slugs.title_for(s) }
              }
            end
            rows[slug] = row
          end

          write(meta_path, rows)
          rows
        end

        #: (Array[String], Array[String]) -> Array[String]
        def self.merge_aliases(existing, absorbed)
          (existing + absorbed).uniq.reject(&:empty?)
        end

        #: (Pathname, Hash[String, Hash[Symbol, untyped]]) -> void
        def self.write(meta_path, rows)
          sorted = rows.values.sort do |a, b|
            (b[:creation_date] <=> a[:creation_date]).nonzero? || (a[:slug] <=> b[:slug])
          end
          lines = [*META_TABLE_HEADER]
          sorted.each do |row|
            title = row[:title] || Slugs.title_for(row[:slug])
            cells = [
              "[[#{title}]]",
              row[:author],
              row[:creation_date],
              row[:modified_date],
              row[:language],
              row[:aliases].join(ALIAS_SEPARATOR)
            ]
            inner = cells.map { |cell| cell.to_s.empty? ? ' ' : " #{cell} " }.join('|')
            lines << "|#{inner}|"
          end
          content = lines.join("\n") << "\n"
          return meta_path.write(content) if !meta_path.exist? || meta_path.read == content

          meta_path.write(content)
        end
      end
    end
  end
end
