# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'

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
        META_HEADERS = ['Title', 'Author', 'Creation date',
                        'Modified date', 'Language', 'Aliases'].freeze #: Array[String]
        META_TABLE_HEADER = [
          "| #{META_HEADERS.join(' | ')} |",
          "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"
        ].freeze #: Array[String]
        ALIAS_SEPARATOR = '<br>' #: String

        #: (Pathname, ?ignore_meta: bool) -> Hash[String, meta_row]
        def self.load(meta_path, ignore_meta: false)
          return {} if ignore_meta
          return {} unless meta_path.exist?

          result = {} #: Hash[String, meta_row]
          meta_path.each_line do |line|
            row = parse_row(line.chomp)
            result[row[:slug]] = row if row
          end
          result
        end

        #: (String) -> meta_row?
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
        # Reads the rows already present in META.md and merges them with
        # what git says. With prev_head available, pages untouched since
        # prev_head keep their row verbatim (incremental sync).
        #: (Wiki, Array[String], Pathname, ?ignore_meta: bool, ?prev_head: String?) -> Hash[String, meta_row]
        def self.sync!(wiki, pages, meta_path, ignore_meta: false, prev_head: nil)
          # diff_paths returns nil for "full rebuild" (ignore_meta or no valid
          # prev_head); it returns the exact list of paths touched since
          # prev_head otherwise.
          previously = load(meta_path, ignore_meta: ignore_meta)
          rows = {} #: Hash[String, meta_row]

          changed = prev_head.nil? || ignore_meta ? nil : wiki.diff_paths(prev_head)

          if changed && changed.empty?
            # Nothing in the repo changed. Honour the existing rows as-is,
            # dropping rows whose pages no longer exist (defensive guard).
            still_current = Set.new(pages.map { |page| File.basename(page, '.md') })
            previously.each { |slug, row| rows[slug] = row }
            pages.each do |page|
              slug = File.basename(page, '.md')
              rows[slug] ||= build_row(wiki, page)
            end
            rows.delete_if { |slug, _| !still_current.include?(slug) }
            write(meta_path, rows)
            return rows
          end

          pages.each do |page|
            slug = File.basename(page, '.md')
            already = previously.key?(slug)
            if !changed.nil? && already && changed.none? { |path| path.b == page.b }
              rows[slug] = previously[slug].dup
              next
            end

            rows[slug] = refresh_row(wiki, page, previously[slug])
          end

          write(meta_path, rows)
          rows
        end

        # Rebuilds one row, refreshing git-derived fields and keeping curated ones.
        #: (Wiki, String, meta_row?) -> meta_row
        def self.refresh_row(wiki, page, previous)
          slug = File.basename(page, '.md')
          bounds = wiki.commit_bounds_for(page)
          last = bounds[:latest]
          renames = wiki.rename_history_for(page)
          aliases = renames.map { |name| Slugs.title_for(File.basename(name, '.md')) }

          if previous
            row = previous.dup
            row[:slug] = slug
            row[:title] = Slugs.title_for(slug)
            row[:modified_date] = last.time.utc.iso8601 if last
            row[:aliases] = merge_aliases(row[:aliases], aliases)
            return row
          end

          build_row(wiki, page, bounds, renames)
        end

        # Builds a fresh row purely from git + text.
        #: (Wiki, String, ?Hash[Symbol, Rugged::Commit?], ?Array[String]) -> meta_row
        def self.build_row(wiki, page, bounds = nil, renames = nil)
          slug = File.basename(page, '.md')
          bounds ||= wiki.commit_bounds_for(page)
          renames ||= wiki.rename_history_for(page)
          last = bounds[:latest]
          first = bounds[:earliest]

          {
            slug: slug,
            title: Slugs.title_for(slug),
            author: first ? first.author[:name] || 'unknown' : 'unknown',
            creation_date: first ? first.time.utc.iso8601 : 'unknown',
            modified_date: last ? last.time.utc.iso8601 : 'unknown',
            language: Language.call(wiki.text_for(page)),
            aliases: renames.map { |name| Slugs.title_for(File.basename(name, '.md')) }
          }
        end

        #: (Array[String], Array[String]) -> Array[String]
        def self.merge_aliases(existing, absorbed)
          (existing + absorbed).uniq.reject(&:empty?)
        end

        #: (Pathname, Hash[String, meta_row]) -> void
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
          return if meta_path.exist? && meta_path.read == content

          meta_path.write(content)
        end
      end
    end
  end
end
