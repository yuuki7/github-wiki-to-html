# frozen_string_literal: true
# rbs_inline: enabled

require 'rugged'
require 'yaml'
require 'fileutils'
require 'time'
require 'whatlanguage'

require_relative 'wiki/slugs'
require_relative 'wiki/language'
require_relative 'wiki/tags'
require_relative 'wiki/meta'

module Wikinder
  module GitHub
    # Represents a GitHub Wiki repository as a coherent set of Markdown pages.
    #
    # The wiki repository contains .md files; this class enumerates them,
    # rewrites wiki-specific syntax, and produces YAML front matter
    # with metadata for downstream consumers.
    #
    # GitHub Wiki is flat: it has no notion of nested page directories, and
    # pages are addressed by name only. Subdirectory blobs are therefore
    # silently unsupported — they are ignored entirely.
    class Wiki
      # @rbs @path: Pathname
      # @rbs @repo: Rugged::Repository
      # @rbs @commit_bounds: Hash[String, Hash[Symbol, Rugged::Commit?]]
      # @rbs @rename_deltas: Hash[String, String]
      # @rbs @rename_cache: Hash[[Rugged::Commit, Rugged::Commit], Array[Rugged::Diff::Delta]]
      # @rbs @diffs: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]
      # @rbs @tree: Rugged::Tree
      # @rbs @ignore_meta: bool
      # @rbs @prev_head: String?

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] unlisted_pages/ungenerated_pages Sets.
      #   ungenerated_pages defaults to Set['Home', 'README', 'LICENSE',
      #   'META', '_Footer'] — the same set the conversion CLI passes —
      #   so Home/_Footer are not emitted as ordinary articles by default.
      #   Pass Set['META'] (or any subset) explicitly to opt out of each.
      # @param options[:ignore_meta] Ignore committed META.md and derive
      #   authorship metadata from git history instead. Used for testing.
      # @param options[:prev_head] SHA of the commit this repo was last read
      #   at. Used for incremental META.md sync.
      #: (String | Pathname, ?wiki_options) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        # Capture the tree once so walking / lookup during build does not
        # change mid-build (the wiki could otherwise move under a build).
        @tree = (@repo.rev_parse(@head) || @repo.head.target).tree
        @ungenerated_pages = Array(
          options.fetch(:ungenerated_pages) { Set['Home', 'README', 'LICENSE', 'META', '_Footer'] }
        ).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
        @ignore_meta = options[:ignore_meta] == true
        prev_head = options[:prev_head]
        @prev_head = prev_head.is_a?(String) ? prev_head : nil
      end

      # Builds the entire output tree, writing Markdown files with YAML front matter.
      #
      # All outputs are computed in memory first; only when computation of
      # every page (or asset) succeeded are files written, each via a
      # same-directory temporary file atomically renamed into place. A crash
      # can therefore leave previous-generation and new files mixed, but
      # never a torn individual file. After the write, files the new build
      # no longer produces are removed (keeping anything unrelated to the
      # build untouched).
      #: (String) -> void
      def build(target_dir)
        outputs = compute_outputs
        verify_confined!(target_dir, outputs)

        FileUtils.mkdir_p(target_dir)
        outputs.each do |relative, content|
          destination = File.join(target_dir, relative)
          FileUtils.mkdir_p(File.dirname(destination))
          temp = "#{destination}.tmp.#{Process.pid}"
          begin
            File.binwrite(temp, content)
            File.rename(temp, destination)
          ensure
            FileUtils.rm_f(temp)
          end
        end

        cleanup_stale_files(target_dir, outputs)
      end

      private

      # Refuses to build when any output path would escape the output
      # directory — callers get a loud error before any filesystem write
      # happens.
      #: (String, Hash[String, String]) -> void
      def verify_confined!(target_dir, outputs)
        base = File.expand_path(target_dir)
        outputs.each_key do |key|
          raise 'error: empty output path in outputs' if key.empty?

          expanded = File.expand_path(key, base)
          next if expanded.start_with?("#{base}#{File::SEPARATOR}")

          raise "error: unsafe output path #{key.inspect} escapes the output directory"
        end
      end

      # Removes stale generated files no longer produced by this build.
      #
      # The output directory is assumed to be exclusively this tool's
      # destination — anything matching the generated extensions (Markdown
      # or common image types) that the current build did not produce is
      # removed, along with `.tmp.<pid>` stragglers from a crash-during-write.
      # Files with other extensions (e.g. site assets shared with the SSG)
      # are left untouched.
      #: (String, Hash[String, String]) -> void
      def cleanup_stale_files(target_dir, outputs)
        keep = Set.new(outputs.keys)
        %w[*.md *.png *.jpg *.jpeg *.gif *.webp *.svg *.tmp.*].each do |pattern|
          Dir.glob(File.join(target_dir, pattern)).each do |path|
            next if keep.include?(File.basename(path))

            FileUtils.rm_f(path)
          end
        end
      end

      # Computes every output the build would produce, returning them as a
      # map of target-relative paths to content. Meta.sync! still mutates
      # META.md in the source tree (that is its job); everything else happens
      # purely in memory.
      #: () -> Hash[String, String]
      def compute_outputs
        outputs = {} #: Hash[String, String]

        pages = collect_pages
        meta_path = Pathname(@path.to_s) / 'META.md'
        meta = Meta.sync!(self, pages, meta_path, ignore_meta: @ignore_meta, prev_head: @prev_head)

        pages.each do |page|
          front_matter = front_matter_with_context(page, meta)
          outputs[File.basename(page)] = "#{front_matter}---\n\n#{render_page_with_context(page)}"
        end

        %w[Home _Footer].each do |name|
          file_name = "#{name}.md"
          next unless tree_entry(file_name)

          outputs[file_name] = special_output(name, file_name)
        end

        occupied = Set.new(meta.keys.map(&:downcase))
        occupied.merge(@ungenerated_pages.map(&:downcase))
        %w[Home _Footer].each do |name|
          occupied << name.downcase if tree_entry("#{name}.md")
        end
        redirect_outputs(meta, occupied).each { |relative, content| outputs[relative] = content }

        image_extensions = %w[.png .jpg .jpeg .gif .webp .svg]
        @tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          next unless root.empty? # subdirectory assets are unsupported and ignored

          path = entry[:name]
          next unless image_extensions.include?(File.extname(path).downcase)
          next if path.start_with?('.') # dotfiles are never wiki assets

          outputs[path] = @repo.lookup(entry[:oid]).content
        end

        outputs
      end

      # Builds the front matter for one page, wrapping any failure with the
      # page path so a crash mid-build identifies the file responsible.
      #: (String, Hash[String, meta_row]) -> String
      def front_matter_with_context(page, meta)
        article_front_matter(page, meta)
      rescue StandardError => e
        raise "could not build front matter for page #{page}: #{e.class}: #{e.message}"
      end

      # Renders one page, wrapping any failure with the page path so a crash
      # mid-build identifies the file responsible.
      #: (String) -> String
      def render_page_with_context(page)
        render_page(page)
      rescue StandardError => e
        raise "could not render page #{page}: #{e.class}: #{e.message}"
      end

      #: (String, String) -> String
      def special_output(name, file_name)
        front_matter = {
          'kind' => 'special',
          'title' => title_for(name),
          'slug' => name,
          'language' => 'en'
        }.to_yaml
        "#{front_matter}---\n\n#{render_page_with_context(file_name)}"
      end

      #: (Hash[String, meta_row], Set[String]) -> Hash[String, String]
      def redirect_outputs(meta, occupied_slugs)
        outputs = {} #: Hash[String, String]
        meta.each do |target_slug, row|
          row[:aliases].each do |title|
            alias_slug = Slugs.for_title(title)
            downcased = alias_slug.downcase
            next if occupied_slugs.include?(downcased) || downcased == target_slug.downcase

            front_matter = {
              'kind' => 'redirect',
              'title' => title,
              'slug' => alias_slug,
              'target_slug' => target_slug,
              'language' => row[:language]
            }.to_yaml
            outputs["#{alias_slug}.md"] = "#{front_matter}---\n\n"
          end
        end
        outputs
      end

      #: () -> Array[String]
      def collect_pages
        result = [] #: Array[String]
        @tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          next unless root.empty? # subdirectory files are unsupported and ignored

          path = entry[:name]
          next unless path.end_with?('.md')
          next if path.start_with?('.') # dotfiles are never wiki pages

          slug = File.basename(path, '.md')
          next unless Slugs.safe?(slug)
          next if @ungenerated_pages.include?(slug)

          result << path
        end
        result.sort!
      end

      public

      # Looks up a path in the HEAD tree. GitHub Wiki is flat, so a plain
      # tree lookup always suffices.
      #: (String, ?tree: Rugged::Tree?) -> Rugged::tree_entry?
      def tree_entry(path, tree: nil)
        (tree || @tree)[path]
      end

      #: (String) -> String
      def text_for(name)
        entry = tree_entry(name)
        return '' unless entry

        content = @repo.lookup(entry[:oid]).content
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

      #: (String) -> Hash[Symbol, Rugged::Commit?]
      def commit_bounds_for(path)
        @commit_bounds ||= {} #: Hash[String, Hash[Symbol, Rugged::Commit?]]
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

        head_commit = @repo.rev_parse(@head)
        return nil unless head_commit

        prev_commit.diff(head_commit)
                   .deltas
                   .flat_map { |delta| [delta.old_file[:path], delta.new_file[:path]] }
                   .uniq
      end

      #: (String) -> Rugged::Commit?
      def rev_parse(from_ref)
        @repo.rev_parse(from_ref)
      rescue Rugged::Error
        nil
      end

      #: (Rugged::Commit, Rugged::Commit) -> Rugged::Diff
      def cached_diff(commit, parent)
        @diffs ||= {} #: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]
        @diffs[[commit, parent]] ||= commit.diff(parent)
      end

      #: (Rugged::Commit, Rugged::Commit) -> Array[Rugged::Diff::Delta]
      def cached_rename_deltas(commit, parent)
        @rename_cache ||= {} #: Hash[[Rugged::Commit, Rugged::Commit], Array[Rugged::Diff::Delta]]
        @rename_cache[[commit, parent]] ||= begin
          d = commit.diff(parent)
          d.find_similar!(renames: true)
          d.deltas
        end
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
      #: () -> Hash[String, String]
      def rename_deltas
        @rename_deltas ||= begin
          map = {} #: Hash[String, String]
          @repo.walk('HEAD').each do |commit|
            commit.parents.each do |parent|
              deltas = cached_rename_deltas(commit, parent)
              marked_renames = Set.new
              deltas.each do |delta|
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
                newer = delta.old_file[:path].dup.force_encoding(Encoding::UTF_8)
                older = delta.new_file[:path].dup.force_encoding(Encoding::UTF_8)
                map[newer] ||= older
                marked_renames.add(newer)
                marked_renames.add(older)
              end
              warn_unlinked_rename(parent, commit, marked_renames)
            end
          end
          map
        end
      end

      # Emits a one-line warning when the commit deletes an .md file and adds
      # another .md file, and the git rename detector found no link between
      # them. This is the usual telltale shape of "rename and fully rewrite".
      # Has no effect on the returned rows; only diagnostics.
      #: (Rugged::Commit, Rugged::Commit, Set[String]) -> void
      def warn_unlinked_rename(parent, commit, marked_renames)
        forward = parent.diff(commit)
        deleted_deltas = forward.deltas.select { |d| d.status == :deleted && md?(d.old_file[:path]) }
        added_deltas = forward.deltas.select { |d| d.status == :added && md?(d.new_file[:path]) }
        deleted_md = deleted_deltas.map { |d| utf8_path(d.old_file[:path]) }
        added_md = added_deltas.map { |d| utf8_path(d.new_file[:path]) }

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

      #: (String) -> String
      def utf8_path(path)
        path.dup.force_encoding(Encoding::UTF_8)
      end

      private

      #: (String) -> String
      def render_page(name)
        Tags.render(text_for(name))
      end

      #: (String) -> String
      def detect_language(text) = Language.call(text)

      #: (Rugged::Commit, String) -> bool
      def touched?(commit, path)
        parents = commit.parents
        return !tree_entry(path, tree: commit.tree).nil? if parents.empty?

        path_b = path.b
        parents.any? do |parent|
          cached_diff(commit, parent).deltas.any? do |delta|
            delta.new_file[:path].b == path_b || delta.old_file[:path].b == path_b
          end
        end
      end

      # The wiki repository is flat: all pages live at the repository root,
      # so a single tree lookup resolves the path.

      #: (String, ?Hash[String, meta_row]) -> String
      def article_front_matter(page_name, meta = {})
        slug = File.basename(page_name, '.md')
        row = meta[slug]
        # Only inspect git history when the META row does not answer the
        # questions — incremental builds rely on previous rows to skip the
        # history walk entirely.
        bounds = row.nil? ? commit_bounds_for(page_name) : nil
        last = bounds && bounds[:latest]
        first = bounds && bounds[:earliest]
        author = if row
                   row[:author]
                 elsif last
                   last.author[:name] || 'unknown'
                 else
                   'unknown'
                 end
        creation_date = if row
                          row[:creation_date]
                        elsif first
                          first.time.utc.iso8601
                        else
                          'unknown'
                        end
        modified_date = if row
                          row[:modified_date]
                        elsif last
                          last.time.utc.iso8601
                        else
                          'unknown'
                        end
        language = row ? row[:language] : detect_language(text_for(page_name))
        front_matter = {
          'kind' => 'article',
          'title' => title_for(slug),
          'slug' => slug,
          'author' => author,
          'creation_date' => creation_date,
          'modified_date' => modified_date,
          'language' => language
        }
        front_matter = front_matter.merge('listed' => false) if @unlisted_pages.include?(slug)
        front_matter.to_yaml
      end

      #: (String) -> String
      def title_for(slug) = Slugs.title_for(slug)
    end
  end
end
