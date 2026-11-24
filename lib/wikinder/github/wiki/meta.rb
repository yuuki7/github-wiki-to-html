# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'strscan'

module Wikinder
  module GitHub
    class Wiki
      # Reads and writes META.md, syncing article rows with git history.
      #
      # META.md holds one row per name: an article row for each
      # page, and a redirect row for each name a page was renamed
      # away from. A redirect row carries only what is its own —
      # the language the page's body had under that name, and the
      # current title it redirects to. The author and dates live
      # on the target's article row alone. Renames are absorbed as
      # redirect rows and retargeted on every further rename, so a
      # redirect always names the current title directly. A
      # redirect row whose language is its target's leaves the
      # cell empty — the target's row already states it — and
      # reading fills it back in, so rows in memory always carry
      # the language itself.
      #
      # Existing article rows are kept — author and creation date
      # are curated by hand — but modified_date is refreshed from
      # git, and rows for missing or deleted pages are rebuilt from
      # history. Language is detected once, when a row is created,
      # and never refreshed: detection is heuristic, and flipping
      # it would silently rewrite a value a human may already have
      # reviewed. A redirect row's language is fixed the same way,
      # inherited from the page's language at the moment of the
      # rename.
      #
      # Redirect rows that would shadow an existing page are
      # dropped; see prune_colliding_aliases!. With ignore_meta
      # set, every article row is rebuilt from history and the
      # committed META.md is disregarded.
      #
      # Files written by older versions, whose last column is
      # Aliases, are still read: each listed alias becomes a
      # redirect row inheriting its page's language, and the file
      # is rewritten in the current form on the next sync.
      #
      # Cells are written with backslash escapes ('\|' for a pipe,
      # '\\' for a backslash) so any value is represented
      # losslessly; newlines flatten to spaces. Hand-written rows
      # without escapes are read leniently — an intentional
      # tolerance, not an option.
      module Meta
        META_HEADERS = ['Title', 'Author', 'Creation date',
                        'Modified date', 'Language', 'Redirect to'].freeze #: Array[String]
        LEGACY_ALIASES_HEADER = 'Aliases' #: String
        LEGACY_ALIAS_SEPARATOR = '<br>' #: String
        META_TABLE_HEADER = [
          "| #{META_HEADERS.join(' | ')} |",
          "| #{Array.new(META_HEADERS.size, '---').join(' | ')} |"
        ].freeze #: Array[String]

        # Escapes a value for one META.md table cell.
        #: (String?) -> String
        def self.escape_cell(text) = text.to_s.gsub('\\', '\\\\\\\\').gsub('|', '\\|').gsub(/[\r\n]+/, ' ').strip

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
          scanner = StringScanner.new(inner)
          until scanner.eos?
            if (escaped = scanner.scan(/\\[\\|]/))
              current << escaped[1].to_s
            elsif scanner.scan('\\')
              current << '\\'
            elsif scanner.scan('|')
              cells << current
              current = +''
            else
              current << scanner.getch.to_s
            end
          end
          cells << current
          cells.map(&:strip)
        end

        # The rows already in META.md, keyed by slug. Empty when
        # ignore_meta is set or the file does not exist.
        #: (Pathname, ?ignore_meta: bool) -> Hash[String, MetaRow]
        def self.load(meta_path, ignore_meta: false)
          return {} if ignore_meta
          return {} unless meta_path.exist?

          # Strip invalid bytes up-front so the parser never raises
          # Encoding::CompatibilityError on a hand-corrupted line.
          lines = meta_path.each_line.map { |line| line.scrub("\u{FFFD}").chomp }
          lines = legacy_lines_to_current(lines) if legacy_format?(lines)

          result = {} #: Hash[String, MetaRow]
          lines.each_with_index do |line, index|
            row = parse_row(line, index + 1)
            next unless row

            raise Error, "META.md: duplicate row for [[#{row.slug}]] on line #{index + 1}" if result.key?(row.slug)

            result[row.slug] = row
          end
          inherit_redirect_languages!(result)
          result
        end

        # Fills a redirect row's empty language cell from the
        # article row it ultimately names. A broken chain — a
        # missing target or a cycle — leaves the cell empty; the
        # sync's resolution reports it.
        #: (Hash[String, MetaRow]) -> void
        def self.inherit_redirect_languages!(rows)
          rows.each_value do |row|
            next unless row.redirect_to && row.language.empty?

            target = redirect_target_row(rows, row)
            rows[row.slug] = row.with(language: target.language) if target
          end
        end

        # The article row a redirect row ultimately names,
        # following any chain of redirect rows; nil when the chain
        # is broken or cyclic.
        #: (Hash[String, MetaRow], MetaRow) -> MetaRow?
        def self.redirect_target_row(rows, row)
          seen = Set.new([row.slug]) #: Set[String]
          current = row
          while (title = current.redirect_to)
            slug = Slugs.for_title(title)
            return nil if seen.include?(slug)

            seen << slug
            target = rows[slug]
            return nil if target.nil?
            return target if target.redirect_to.nil?

            current = target
          end
          nil
        end

        # Whether the file still uses the legacy Aliases column,
        # judged by its header row alone.
        #: (Array[String]) -> bool
        def self.legacy_format?(lines)
          lines.any? do |line|
            cells = split_cells(line)
            cells[0] == 'Title' && cells.include?(LEGACY_ALIASES_HEADER)
          end
        end

        # Rewrites legacy lines in the current form, in memory:
        # each article line keeps its cells with an empty redirect
        # cell, and each alias it lists becomes a redirect row of
        # its own, inheriting the article's language. An alias
        # whose slug an article already bears is dropped — the
        # existing page always wins — and an alias listed by more
        # than one article is dropped with a warning, as the sync's
        # pruning drops contested aliases. Diagnostics from the
        # parse that follows cite the rewritten lines, not the
        # original ones; the file itself is rewritten in the
        # current form on the next sync.
        #: (Array[String]) -> Array[String]
        def self.legacy_lines_to_current(lines)
          articles = [] #: Array[Array[String]]
          article_slugs = Set.new #: Set[String]
          lines.each do |line|
            cells = split_cells(line)
            next if cells.empty? || cells.all? { |cell| cell.match?(/\A-+\z/) }
            next if cells.length == 1 && cells[0].empty?
            next if cells[0] == 'Title'

            articles << cells
            article_slugs << Slugs.for_title(cells[0].to_s[2...-2].to_s.strip) if cells[0].to_s.start_with?('[[')
          end

          emitted = Set.new #: Set[String]
          rewritten = [*META_TABLE_HEADER] #: Array[String]
          articles.each do |cells|
            # A row of the wrong width passes through untouched, so
            # the parse raises its usual error for it.
            if cells.length != META_HEADERS.length
              rewritten << table_line(cells)
              next
            end
            title = cells[0].to_s[2...-2].to_s.strip
            rewritten << table_line([cells[0].to_s, cells[1].to_s, cells[2].to_s, cells[3].to_s, cells[4].to_s, ''])
            cells[5].to_s.split(LEGACY_ALIAS_SEPARATOR).map(&:strip).reject(&:empty?).each do |alias_title|
              alias_slug = Slugs.for_title(alias_title)
              next if article_slugs.include?(alias_slug)

              if emitted.include?(alias_slug)
                warn "META.md: alias #{alias_title.inspect} is claimed by more than one page; ignoring it"
                next
              end

              emitted << alias_slug
              rewritten << table_line(["[[#{alias_title}]]", '', '', '', cells[4].to_s, "[[#{title}]]"])
            end
          end
          rewritten
        end

        # One META.md table line for the given raw cell values,
        # escaped and padded the way write emits them.
        #: (Array[String]) -> String
        def self.table_line(values)
          cells = values.map { |value| escape_cell(value) }
          inner = cells.map { |cell| cell.empty? ? ' ' : " #{cell} " }.join('|')
          "|#{inner}|"
        end

        #: (String, ?Integer?) -> MetaRow?
        # Line numbers are only used for diagnostics. A broken row
        # is a fatal error, not a skip: the sync rewrites META.md
        # from the rows it read, so skipping one would silently
        # lose its curated fields. A hand edit that breaks a row
        # must be fixed, not silently absorbed.
        def self.parse_row(line, line_number = nil)
          location = line_number ? " (line #{line_number})" : ''
          cells = split_cells(line)
          return nil if cells.empty?
          return nil if cells.all? { |cell| cell.match?(/\A-+\z/) }
          # A single empty cell is a stray blank line, not a header row.
          return nil if cells.length == 1 && cells[0].empty?

          # The header row is a normal part of every META.md; skip it quietly.
          return nil if cells[0] == 'Title'

          raise Error, "META.md: row has too few cells#{location}" if cells.length < META_HEADERS.length

          if cells.length > META_HEADERS.length
            raise Error, "META.md: row has #{cells.length - META_HEADERS.length} extra cell(s)#{location}"
          end

          title_cell = cells[0]
          unless title_cell.start_with?('[[') && title_cell.end_with?(']]')
            raise Error, "META.md: row without a [[Title]] cell#{location}"
          end

          title = title_cell[2...-2].to_s.strip
          raise Error, "META.md: row with an empty [[]] cell#{location}" if title.empty?

          redirect_cell = cells[5].to_s.strip
          redirect_to = nil #: String?
          unless redirect_cell.empty?
            unless redirect_cell.start_with?('[[') && redirect_cell.end_with?(']]')
              raise Error, "META.md: redirect row without a [[Title]] target#{location}"
            end

            redirect_to = redirect_cell[2...-2].to_s.strip
            raise Error, "META.md: redirect row with an empty [[]] target#{location}" if redirect_to.empty?
          end

          MetaRow.new(
            slug: Slugs.for_title(title),
            title:,
            author: cells[1],
            creation_date: cells[2],
            modified_date: cells[3],
            language: cells[4],
            redirect_to:
          )
        end

        # Computes the synced META rows for the given pages, keyed
        # by slug. Writing them back is Meta.write's job, kept
        # separate so that computing a build never mutates the
        # source tree. With prev_head available, pages untouched
        # since prev_head keep their row verbatim (incremental sync).
        #: (Wiki, Array[String], Pathname, ?ignore_meta: bool, ?prev_head: String?) -> Hash[String, MetaRow]
        def self.sync(wiki, pages, meta_path, ignore_meta: false, prev_head: nil)
          # diff_paths returns nil for "full rebuild" (ignore_meta or no valid
          # prev_head); it returns the exact list of paths touched since
          # prev_head otherwise.
          previously = load(meta_path, ignore_meta:)
          rows = {} #: Hash[String, MetaRow]

          changed = prev_head.nil? || ignore_meta ? nil : wiki.diff_paths(prev_head)

          if changed && changed.empty?
            # No page changed since prev_head, but META.md itself
            # may have drifted (reverted or hand-edited). Keep the
            # rows already read, but rebuild rows for pages they no
            # longer cover — via refresh_row, so rename inheritance
            # and curated fields are honoured exactly as in a full
            # rebuild, not dropped to git-derived defaults.
            # Redirect rows are kept as read, and renames are
            # absorbed as in a full rebuild: the drift may be a
            # META.md reverted to a pre-rename state, whose rows no
            # longer cover a renamed page at all.
            still_current = Set.new(pages.map { File.basename(it, '.md') })
            previously.each { |slug, row| rows[slug] = row }
            pages.each do |page|
              slug = File.basename(page, '.md')
              current = rows[slug]
              next if current && current.redirect_to.nil?

              rows[slug] = refresh_row(wiki, page, inherited_row(wiki, previously, page, slug))
            end
            rows.keep_if { |slug, row| row.redirect_to || still_current.include?(slug) }
            absorb_renames!(wiki, pages, rows)
            resolve_redirect_rows!(rows)
            prune_colliding_aliases!(rows, pages, wiki.ungenerated_pages)
            return rows
          end

          previously.each_value { |row| rows[row.slug] = row if row.redirect_to }
          pages.each do |page|
            slug = File.basename(page, '.md')
            inherited = inherited_row(wiki, previously, page, slug)
            if !changed.nil? && inherited && changed.none? { |path| path.b == page.b }
              rows[slug] = inherited.with(slug:, title: Slugs.title_for(slug), redirect_to: nil)
              next
            end

            rows[slug] = refresh_row(wiki, page, inherited)
          end

          absorb_renames!(wiki, pages, rows)
          resolve_redirect_rows!(rows)
          prune_colliding_aliases!(rows, pages, wiki.ungenerated_pages)
          rows
        end

        # Turns every name a page was renamed away from into a
        # redirect row for that page, and retargets redirect rows
        # whose target was itself renamed away, so a redirect
        # always names the current title directly. A new redirect
        # row inherits the page's language: that is the language
        # the page's body had under the old name, unless a human
        # has recorded otherwise on an existing row — an existing
        # row keeps its language, and only its target moves.
        #
        # A name absorbed by more than one page is dropped with a
        # warning: a redirect can have only one healthy target, and
        # letting the last page win would hide the ambiguity.
        #: (Wiki, Array[String], Hash[String, MetaRow]) -> void
        def self.absorb_renames!(wiki, pages, rows)
          absorbed_by = Hash.new { |hash, key| hash[key] = [] } #: Hash[String, Array[String]]
          pages.each do |page|
            slug = File.basename(page, '.md')
            page_row = rows.fetch(slug)
            predecessors = wiki.rename_history_for(page).map { File.basename(it, '.md') }
            predecessors.each do |predecessor|
              title = Slugs.title_for(predecessor)
              alias_slug = Slugs.for_title(title)
              next if alias_slug == slug

              absorbed_by[alias_slug] << slug
              existing = rows[alias_slug]
              if existing.nil?
                rows[alias_slug] = MetaRow.new(
                  slug: alias_slug, title:, author: '', creation_date: '',
                  modified_date: '', language: page_row.language,
                  redirect_to: page_row.title
                )
              elsif existing.redirect_to
                target_slug = Slugs.for_title(existing.redirect_to)
                if target_slug != slug && predecessors.include?(target_slug)
                  rows[alias_slug] = existing.with(redirect_to: page_row.title)
                end
              end
            end
          end

          absorbed_by.each do |alias_slug, claimants|
            owners = claimants.uniq
            next if owners.length <= 1

            row = rows[alias_slug]
            next unless row&.redirect_to

            names = owners.map { |slug| "[[#{Slugs.title_for(slug)}]]" }.sort.join(', ')
            warn "META.md: alias #{row.title.inspect} is claimed by #{names}; ignoring it"
            rows.delete(alias_slug)
          end
        end

        # Flattens every redirect row onto the article row it
        # ultimately names, following chains a hand edit may have
        # written. A target with no row, or a cycle, is a fatal
        # error, not a skip: the sync rewrites META.md from the
        # rows it read, so absorbing a broken redirect silently
        # would lose it or emit a redirect to nowhere.
        #: (Hash[String, MetaRow]) -> void
        def self.resolve_redirect_rows!(rows)
          rows.each_value do |row|
            next unless row.redirect_to

            target_slug = Slugs.for_title(row.redirect_to)
            seen = Set.new([row.slug]) #: Set[String]
            while (target = rows[target_slug]) && (next_title = target.redirect_to)
              raise Error, "META.md: redirect cycle at [[#{row.title}]]" if seen.include?(target_slug)

              seen << target_slug
              target_slug = Slugs.for_title(next_title)
            end
            target = rows[target_slug]
            if target.nil?
              raise Error, "META.md: [[#{row.title}]] redirects to [[#{row.redirect_to}]], which has no row"
            end

            rows[row.slug] = row.with(redirect_to: target.title) if target.title != row.redirect_to
          end
        end

        # Drops redirect rows that name a slug already used by an
        # existing page (generated or ungenerated), or that point
        # at themselves. Such a redirect would shadow the page —
        # the existing page always wins — so the row is removed
        # from META.md itself: a renamed-away name cannot be
        # re-added by an automated pass, and a curated redirect
        # since claimed by another page is dropped instead of
        # shadowing it.
        #
        # Comparison is case-insensitive: the output may live on a
        # case-insensitive filesystem.
        #: (Hash[String, MetaRow], Array[String], Set[String]) -> void
        def self.prune_colliding_aliases!(rows, pages, ungenerated_pages)
          occupied = Set.new(ungenerated_pages.map(&:downcase))
          pages.each { occupied << File.basename(it, '.md').downcase }

          rows.each_key do |slug|
            row = rows.fetch(slug)
            next unless row.redirect_to

            unless Slugs.safe?(row.slug)
              warn "META.md: ignoring unsafe alias #{row.title.inspect}; it would not produce a valid page"
              rows.delete(slug)
              next
            end

            target_slug = Slugs.for_title(row.redirect_to)
            rows.delete(slug) if slug.downcase == target_slug.downcase || occupied.include?(slug.downcase)
          end
        end

        # Finds the article row to inherit for a page, trying the
        # current slug first and every predecessor slug from rename
        # history otherwise. Redirect rows are never inherited: they
        # carry none of an article row's curated fields.
        #: (Wiki, Hash[String, MetaRow], String, String) -> MetaRow?
        def self.inherited_row(wiki, previously, page, slug)
          row = previously[slug]
          return row if row && row.redirect_to.nil?

          wiki.rename_history_for(page).each do |predecessor|
            row = previously[File.basename(predecessor, '.md')]
            return row if row && row.redirect_to.nil?
          end
          nil
        end

        # Rebuilds one article row, refreshing git-derived fields
        # and keeping curated ones.
        #: (Wiki, String, MetaRow?) -> MetaRow
        def self.refresh_row(wiki, page, previous)
          slug = File.basename(page, '.md')
          bounds = wiki.commit_bounds_for(page)
          last = bounds[:latest]

          if previous
            return previous.with(
              slug:,
              title: Slugs.title_for(slug),
              modified_date: last ? last.time.utc.iso8601 : previous.modified_date,
              redirect_to: nil
            )
          end

          build_row(wiki, page, bounds)
        end

        # Builds a fresh article row from git history and the
        # page's own text.
        #: (Wiki, String, ?commit_bounds) -> MetaRow
        def self.build_row(wiki, page, bounds = nil)
          slug = File.basename(page, '.md')
          bounds ||= wiki.commit_bounds_for(page)
          last = bounds[:latest]
          first = bounds[:earliest]

          raise Error, "page #{slug} has no git history; its author and dates cannot be determined" unless first && last

          MetaRow.new(
            slug:,
            title: Slugs.title_for(slug),
            author: first.author[:name],
            creation_date: first.time.utc.iso8601,
            modified_date: last.time.utc.iso8601,
            language: Language.call(wiki.text_for(page), supported: wiki.supported_languages),
            redirect_to: nil
          )
        end

        # Writes the rows as the META.md table: newest first by
        # creation date, ties broken by slug. A redirect row sorts
        # by its target's creation date and follows article rows on
        # a tie, so a renamed-away name sits near the page it names.
        # Does nothing when the file already holds exactly this
        # content.
        #: (Pathname, Hash[String, MetaRow]) -> void
        def self.write(meta_path, rows)
          sorted = rows.values.sort do |a, b|
            (sort_date(b, rows) <=> sort_date(a, rows)).nonzero? ||
              ((a.redirect_to ? 1 : 0) <=> (b.redirect_to ? 1 : 0)).nonzero? ||
              (a.slug <=> b.slug)
          end
          lines = [*META_TABLE_HEADER]
          sorted.each do |row|
            lines << table_line([
                                  "[[#{row.title}]]",
                                  row.author,
                                  row.creation_date,
                                  row.modified_date,
                                  written_language(row, rows),
                                  row.redirect_to ? "[[#{row.redirect_to}]]" : ''
                                ])
          end
          content = lines.join("\n") << "\n"
          return if meta_path.exist? && meta_path.read == content

          write_atomically(meta_path, content)
        end

        # The language a row's cell carries in the file: a
        # redirect row whose language is its target's writes an
        # empty cell, since the target's row already states it.
        #: (MetaRow, Hash[String, MetaRow]) -> String
        def self.written_language(row, rows)
          return row.language unless row.redirect_to

          target = redirect_target_row(rows, row)
          target && target.language == row.language ? '' : row.language
        end

        # The creation date a row sorts by: its own, or — for a
        # redirect row, which keeps no dates of its own — its
        # target's.
        #: (MetaRow, Hash[String, MetaRow]) -> String
        def self.sort_date(row, rows)
          return row.creation_date unless row.redirect_to

          target = rows[Slugs.for_title(row.redirect_to)]
          target ? target.creation_date : ''
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
