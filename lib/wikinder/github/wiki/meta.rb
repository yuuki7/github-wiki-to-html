# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'

module Wikinder
  module GitHub
    class Wiki
      # Reads and writes META.md, syncing article rows with git history.
      #
      # Existing rows are kept (author, creation date, aliases are curated
      # by hand), but modified_date is refreshed from git and rows for
      # missing or deleted pages are rebuilt from history. Language is
      # detected once, when a row is created, and never refreshed — the
      # detection is heuristic and flipping it after the fact would silently
      # rewrite a value a human may already have reviewed.
      #
      # Aliases that slugify to a name already used by an existing page are
      # dropped instead of rendering a redirect there: the existing page
      # always wins over a generated redirect.
      #
      # With ignore_meta set, every row is rebuilt from history and the
      # previously committed META.md is disregarded.
      #
      # Cells are written with backslash escapes — '\|' for a literal pipe
      # and '\\' for a literal backslash — so any author or title can be
      # represented losslessly. Newlines inside a value are flattened to
      # spaces. Hand-written rows without escapes are read leniently, and
      # those tolerances are intentional rather than optional.
      module Meta
        META_HEADERS = ['Title', 'Author', 'Creation date',
                        'Modified date', 'Language', 'Aliases'].freeze #: Array[String]
        META_TABLE_HEADER = [
          "| #{META_HEADERS.join(' | ')} |",
          "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"
        ].freeze #: Array[String]
        ALIAS_SEPARATOR = '<br>' #: String

        #: (String?) -> String
        def self.escape_cell(text)
          text.to_s.gsub('\\', '\\\\\\\\').gsub('|', '\\|').gsub(/[\r\n]+/, ' ').strip
        end

        # Splits a table line into cells, undressing the backslash escapes.
        # Handles '\\' and '\|' as two-character sequences; a backslash
        # followed by any other byte is kept verbatim.
        #: (String) -> Array[String]
        def self.split_cells(line)
          body = line.chomp
          return [] unless body.start_with?('|') && body.end_with?('|')

          inner = body[1..-2] || ''
          cells = [] #: Array[String]
          current = +''
          i = 0
          while i < inner.length
            ch = inner[i]
            break if ch.nil? # cannot happen, satisfies the type checker

            if ch == '\\'
              nxt = inner[i + 1]
              if nxt && ['\\', '|'].include?(nxt)
                current << nxt
                i += 2
                next
              end
              current << ch
              i += 1
              next
            end
            if ch == '|'
              cells << current
              current = +''
              i += 1
              next
            end
            current << ch
            i += 1
          end
          cells << current
          cells.map(&:strip)
        end

        #: (Pathname, ?ignore_meta: bool) -> Hash[String, meta_row]
        def self.load(meta_path, ignore_meta: false)
          return {} if ignore_meta
          return {} unless meta_path.exist?

          result = {} #: Hash[String, meta_row]
          meta_path.each_line.with_index(1) do |line, index|
            row = parse_row(line.chomp, index)
            next unless row

            if result.key?(row[:slug])
              warn "META.md: duplicate row for [[#{row[:slug]}]] on line #{index}; keeping the last"
            end
            result[row[:slug]] = row
          end
          result
        end

        #: (String, ?Integer, Integer?) -> meta_row?
        # Line numbers are only used for diagnostics; the parser is tolerant
        # of broken rows (they are skipped with a warning), because a hand
        # edit should never make the sync crash.
        def self.parse_row(line, line_number = nil)
          location = line_number ? " (line #{line_number})" : ''
          cells = split_cells(line)
          return nil if cells.empty?
          return nil if cells.all? { |cell| cell.match?(/\A-+\z/) }
          return nil if cells[0] == 'Title' || (cells.length == 1 && cells[0].empty?)

          if cells.length < META_HEADERS.length
            warn "META.md: ignoring row with too few cells#{location}"
            return nil
          end
          if cells.length > META_HEADERS.length
            warn "META.md: ignoring #{cells.length - META_HEADERS.length} extra cell(s)#{location}"
            cells = cells.first(META_HEADERS.length)
          end

          title_cell = cells[0]
          unless title_cell.start_with?('[[') && title_cell.end_with?(']]')
            warn "META.md: ignoring row without a [[Title]] cell#{location}"
            return nil
          end

          title = title_cell[2...-2].to_s.strip
          if title.empty?
            warn "META.md: ignoring row with an empty [[]] cell#{location}"
            return nil
          end

          {
            slug: Slugs.for_title(title),
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
            # Nothing in the changes itself, but META.md may have drifted from
            # this repo (reverted or hand-edited). Keep the rows we already
            # have, but rebuild rows for pages the rows no longer cover —
            # via refresh_row, so rename inheritance and curated fields are
            # honoured exactly as in a full rebuild, not dropped to
            # git-derived defaults.
            still_current = Set.new(pages.map { |page| File.basename(page, '.md') })
            previously.each { |slug, row| rows[slug] = row }
            pages.each do |page|
              slug = File.basename(page, '.md')
              rows[slug] ||= refresh_row(wiki, page, inherited_row(wiki, previously, page, slug))
            end
            rows.delete_if { |slug, _| !still_current.include?(slug) }
            rows.delete_if { |slug, _| !still_current.include?(slug) }
            prune_colliding_aliases!(rows, pages, wiki.ungenerated_pages)
            write(meta_path, rows)
            return rows
          end

          pages.each do |page|
            slug = File.basename(page, '.md')
            inherited = inherited_row(wiki, previously, page, slug)
            if !changed.nil? && inherited && changed.none? { |path| path.b == page.b }
              row = inherited.dup
              row[:slug] = slug
              row[:title] = Slugs.title_for(slug)
              rows[slug] = row
              next
            end

            rows[slug] = refresh_row(wiki, page, inherited)
          end

          prune_colliding_aliases!(rows, pages, wiki.ungenerated_pages)
          write(meta_path, rows)
          rows
        end

        # Drops aliases that slugify to a name already used by an existing
        # page (generated or ungenerated), or to the row's own slug.
        #
        # An alias that resolves to the same slug as an existing page would
        # produce a redirect file that shadows it — the existing page always
        # wins. This also removes the stale alias from META.md itself, so a
        # renamed-away name cannot be re-added by an automated pass, and a
        # hand-curated alias whose name has since been claimed by another
        # page is removed instead of shadowing it.
        #
        # Additionally, an alias claimed by more than one page's row is
        # dropped from *every* claimant and reported: a redirect file can
        # only have one healthy target, and silently letting the last page
        # win would hide the ambiguity regardless of write order.
        #
        # Comparison is case-insensitive because the output target may live
        # on a case-insensitive filesystem.
        #: (Hash[String, meta_row], Array[String], Set[String]) -> void
        def self.prune_colliding_aliases!(rows, pages, ungenerated_pages)
          occupied = Set.new(ungenerated_pages.map(&:downcase))
          pages.each { |page| occupied << File.basename(page, '.md').downcase }

          rows.each_value do |row|
            row[:aliases] = row[:aliases].reject do |title|
              slug = Slugs.for_title(title).downcase
              unless Slugs.safe?(slug)
                warn "META.md: ignoring unsafe alias #{title.inspect}; it would not produce a valid page"
                next true
              end
              slug == row[:slug].to_s.downcase || occupied.include?(slug)
            end
          end

          claims = Hash.new { |hash, key| hash[key] = [] }
          rows.each_value do |row|
            row[:aliases].each do |title|
              claims[Slugs.for_title(title).downcase] << [row, title]
            end
          end
          claims.each_value do |pairs|
            claimants = pairs.map(&:first).uniq
            next if claimants.length <= 1

            # Use a stable owner list for the warning so the same set of
            # pages always produces the same diagnosis.
            owners = claimants.map { |row| "[[#{row[:slug]}]]" }.sort.join(', ')
            warn "META.md: alias #{pairs.first[1].inspect} is claimed by #{owners}; ignoring it"
            pairs.map(&:first).uniq.each do |row|
              titles = pairs.select { |listed, _| listed.equal?(row) }.map(&:last)
              row[:aliases] = row[:aliases] - titles
            end
          end
        end

        # Finds the row to inherit for a page, trying the current slug first
        # and every predecessor slug from rename history otherwise.
        #: (Wiki, Hash[String, meta_row], String, String) -> meta_row?
        def self.inherited_row(wiki, previously, page, slug)
          return previously[slug] if previously.key?(slug)

          wiki.rename_history_for(page).each do |predecessor|
            row = previously[File.basename(predecessor, '.md')]
            return row if row
          end
          nil
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
            (b[:creation_date].to_s <=> a[:creation_date].to_s).nonzero? ||
              (a[:slug].to_s <=> b[:slug].to_s)
          end
          lines = [*META_TABLE_HEADER]
          sorted.each do |row|
            title = row[:title] || Slugs.title_for(row[:slug])
            cells = [
              "[[#{escape_cell(title)}]]",
              escape_cell(row[:author]),
              escape_cell(row[:creation_date]),
              escape_cell(row[:modified_date]),
              escape_cell(row[:language]),
              escape_cell(row[:aliases].join(ALIAS_SEPARATOR))
            ]
            inner = cells.map { |cell| cell.empty? ? ' ' : " #{cell} " }.join('|')
            lines << "|#{inner}|"
          end
          content = lines.join("\n") << "\n"
          return if meta_path.exist? && meta_path.read == content

          write_atomically(meta_path, content)
        end

        # Writes via a temporary file so a crash mid-write can never leave
        # META.md truncated or half-written for the next invocation.
        #: (Pathname, String) -> void
        def self.write_atomically(meta_path, content)
          temp = "#{meta_path}.tmp.#{Process.pid}"
          begin
            File.write(temp, content)
            File.rename(temp, meta_path)
          ensure
            FileUtils.rm_f(temp)
          end
        end
      end
    end
  end
end
