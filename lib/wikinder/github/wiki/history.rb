# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Reads the wiki's git history: the HEAD tree's contents,
      # the commits that touched each page (following renames),
      # the rename map across the whole history, and the paths
      # changed between two refs. Everything the converter
      # derives from git lives here, so Wiki itself only
      # orchestrates the build. Results are cached per instance:
      # a build reads the same history many times, and the
      # repository does not move under it.
      class History
        # @rbs @repo: Rugged::Repository
        # @rbs @head: String
        # @rbs @tree: Rugged::Tree?
        # @rbs @commit_bounds: Hash[String, commit_bounds]
        # @rbs @rename_deltas: Hash[String, String]
        # @rbs @diffs: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]

        attr_reader :head_commit #: Rugged::Commit?

        #: (Rugged::Repository, String) -> void
        def initialize(repo, head)
          @repo = repo
          @head = head
          @head_commit = rev_parse(head)
        end

        # The HEAD tree, from the head commit. Nil when HEAD
        # does not name a commit; Wiki refuses that case before
        # any lookup happens.
        #: -> Rugged::Tree?
        def tree
          @tree ||= @head_commit&.tree
        end

        # Looks up a path in the HEAD tree. GitHub Wiki is flat, so a plain
        # tree lookup always suffices.
        #: (String, ?tree: Rugged::Tree?) -> Rugged::tree_entry?
        def tree_entry(path, tree: nil)
          resolved = tree || self.tree
          return nil unless resolved

          resolved[path]
        end

        # The text of a page or file in the wiki. Line endings and
        # encoding are normalized for the parser; see the notes
        # inline.
        #: (String) -> String
        def text_for(name)
          entry = tree_entry(name)
          return '' unless entry

          blob = @repo.lookup(entry[:oid])
          return '' unless blob.is_a?(Rugged::Blob)

          content = blob.content
          # Normalise CR and CRLF line endings; the Commonmarker parser walks
          # \r\n and bare \r as distinct line separators, so CR-only files
          # would otherwise crash range_for with offsets past the end of
          # line_offsets. This mirrors Gollum's Wiki#normalize.
          content = content.gsub(/\r\n?/, "\n")
          content = content.force_encoding(Encoding::UTF_8)
          return content if content.valid_encoding?

          warn "text_for: #{name} contains invalid UTF-8; invalid bytes were replaced with U+FFFD"
          content.scrub
        end

        # The earliest and latest commits that touched a page,
        # following its renames. When META.md has no row for the page,
        # these commits are the source of its author and dates.
        #: (String) -> commit_bounds
        def commit_bounds_for(path)
          @commit_bounds ||= {} #: Hash[String, commit_bounds]
          return @commit_bounds[path] if @commit_bounds.key?(path)

          earliest = nil #: Rugged::Commit?
          latest = nil #: Rugged::Commit?
          # Include commits that touched any of the paths this page was
          # renamed from, so tree/time bounds reflect the history of the
          # logical page across renames.
          paths = [path] + rename_history_for(path)
          @repo.walk('HEAD').each do |commit|
            next unless paths.any? { |candidate| touched?(commit, candidate) }

            time = commit.time
            earliest = commit if earliest.nil? || time < earliest.time
            latest = commit if latest.nil? || time > latest.time
          end
          @commit_bounds[path] = { earliest: earliest, latest: latest }
        end

        # Returns the file paths changed between two refs. A full rebuild
        # returns nil (meaning "everything changed") so the sync treats every
        # page as changed and rewrites every row.
        #: (String?) -> Array[String]?
        def diff_paths(from_ref)
          return nil if from_ref.nil?
          return [] if from_ref == @head

          prev_commit = rev_parse(from_ref)
          return nil unless prev_commit

          head_commit = rev_parse(@head)
          return nil unless head_commit

          prev_commit.diff(head_commit)
                     .deltas
                     .flat_map { |delta| [delta.old_file[:path], delta.new_file[:path]] }
                     .compact
                     .uniq
        end

        #: (String) -> Rugged::Commit?
        def rev_parse(from_ref)
          commit = @repo.rev_parse(from_ref)
          commit if commit.is_a?(Rugged::Commit)
        rescue Rugged::Error
          nil
        end

        #: (Rugged::Commit, Rugged::Commit) -> Rugged::Diff
        def cached_diff(commit, parent)
          @diffs ||= {} #: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]
          @diffs[[commit, parent]] ||= commit.diff(parent)
        end

        # Returns the file paths this page was renamed from, most recent first,
        # based on git rename detection across history.
        #: (String) -> Array[String]
        def rename_history_for(path)
          renames = rename_deltas #: Hash[String, String]
          result = [] #: Array[String]
          current = path #: String
          visited = [current] #: Array[String]
          until (predecessor = renames[current]).nil?
            break if visited.include?(predecessor) # guard against rename cycles

            result << predecessor
            current = predecessor
            visited << current
          end
          result
        end

        # Builds a map of rename deltas across the full history: every file path
        # that was ever renamed maps to its predecessor path.
        # Additionally, surface a warning when a single commit deletes one
        # .md file and adds another .md file with no detectable rename —
        # that is the most likely shape of a rename+rewrite that git cannot
        # link statistically. The wiki schema can only pick one answer when
        # similarity is low, so the author should curate the alias by hand.
        #
        # One diff is computed per (commit, parent) pair and shared with
        # touched? through cached_diff. The plain delta list is snapshotted
        # before find_similar! runs, because similarity detection consumes
        # exactly the added/deleted pairs warn_unlinked_rename looks for.
        #: () -> Hash[String, String]
        def rename_deltas
          @rename_deltas ||= begin
            map = {} #: Hash[String, String]
            @repo.walk('HEAD').each do |commit|
              commit.parents.each do |parent|
                diff = cached_diff(commit, parent)
                plain = plain_delta_paths(diff)
                diff.find_similar!(renames: true)
                marked_renames = Set.new
                diff.deltas.each do |delta|
                  next unless delta.status == :renamed

                  # Rugged's +commit.diff(parent)+ reports the commit side as
                  # old_file and the parent side as new_file (chronologically
                  # reversed). The rename map therefore reads "current name ->
                  # name it was renamed from". First seen wins; walked from
                  # HEAD so the most recent rename is recorded first.
                  #
                  # The paths are normalised to valid UTF-8 here so all
                  # downstream consumers (slug/alias handling, front-matter
                  # YAML) can treat them as plain Strings without ever having
                  # to worry about ASCII-8BIT.
                  newer_path = delta.old_file[:path]
                  older_path = delta.new_file[:path]
                  next unless newer_path && older_path

                  newer = newer_path.dup.force_encoding(Encoding::UTF_8)
                  older = older_path.dup.force_encoding(Encoding::UTF_8)
                  map[newer] ||= older
                  marked_renames.add(newer)
                  marked_renames.add(older)
                end
                warn_unlinked_rename(plain, marked_renames)
              end
            end
            map
          end
        end

        # Snapshots a diff's [status, path] pairs before rename detection
        # rewrites them. Paths are normalised to UTF-8 like the rename
        # map's, so they can be compared against it directly.
        #: (Rugged::Diff) -> Array[[Symbol, String]]
        def plain_delta_paths(diff)
          diff.deltas.map do |delta|
            [delta.status, delta.old_file[:path].to_s.dup.force_encoding(Encoding::UTF_8)]
          end
        end

        # Emits a one-line warning when the commit deletes an .md file and adds
        # another .md file, and the git rename detector found no link between
        # them. This is the usual telltale shape of "rename and fully rewrite".
        # Has no effect on the returned rows; only diagnostics.
        #
        # +plain+ is the pre-similarity snapshot of the reversed diff
        # (commit side as old), so a forward deletion appears as :added
        # and a forward addition as :deleted.
        #: (Array[[Symbol, String]], Set[String]) -> void
        def warn_unlinked_rename(plain, marked_renames)
          deleted_md = [] #: Array[String]
          added_md = [] #: Array[String]
          plain.each do |status, path|
            next unless md?(path)

            deleted_md << path if status == :added
            added_md << path if status == :deleted
          end

          unmatched_deleted = deleted_md - marked_renames.to_a
          unmatched_added = added_md - marked_renames.to_a
          return if unmatched_deleted.empty? || unmatched_added.empty?

          deleted_list = unmatched_deleted.uniq.join(', ')
          added_list = unmatched_added.uniq.join(', ')
          warn 'git could not link this rename: ' \
               "#{added_list} seems to succeed #{deleted_list} after a heavy rewrite; " \
               'alias must be set in META.md manually'
        end

        #: (String) -> bool
        def md?(path)
          path.end_with?('.md')
        end

        # Whether a commit touched a path. A root commit touches
        # every path in its tree.
        #: (Rugged::Commit, String) -> bool
        def touched?(commit, path)
          parents = commit.parents
          return !tree_entry(path, tree: commit.tree).nil? if parents.empty?

          path_b = path.b
          parents.any? do |parent|
            cached_diff(commit, parent).deltas.any? do |delta|
              delta.new_file[:path]&.b == path_b || delta.old_file[:path]&.b == path_b
            end
          end
        end
      end
    end
  end
end
