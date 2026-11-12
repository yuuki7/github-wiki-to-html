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
    class Wiki
      # @rbs @path: Pathname
      # @rbs @repo: Rugged::Repository
      # @rbs @commit_bounds: Hash[String, Hash[Symbol, Rugged::Commit?]]
      # @rbs @rename_deltas: Hash[String, String]
      # @rbs @ignore_meta: bool
      # @rbs @prev_head: String?

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] unlisted_pages/ungenerated_pages Sets.
      # @param options[:ignore_meta] Ignore committed META.md and derive
      #   authorship metadata from git history instead. Used for testing.
      # @param options[:prev_head] SHA of the commit this repo was last read
      #   at. Used for incremental META.md sync.
      #: (String | Pathname, ?wiki_options) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        @ungenerated_pages = Array(options[:ungenerated_pages] || []).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
        @ignore_meta = options[:ignore_meta] == true
        prev_head = options[:prev_head]
        @prev_head = prev_head.is_a?(String) ? prev_head : nil
      end

      # Builds the entire output tree, writing Markdown files with YAML front matter.
      # Builds the entire output tree, writing Markdown files with YAML front matter.
      #: (String) -> void
      def build(target_dir)
        # Remove old output, keep any unrelated files in target_dir.
        %w[*.md *.png *.jpg *.jpeg *.gif *.webp *.svg].each do |pattern|
          rm_dir_glob(target_dir, pattern)
        end
        FileUtils.mkdir_p(target_dir)

        pages = collect_pages
        meta_path = Pathname(@path.to_s) / 'META.md'
        meta = Meta.sync!(self, pages, meta_path, ignore_meta: @ignore_meta, prev_head: @prev_head)

        pages.each do |page|
          front_matter = article_front_matter(page, meta)
          File.write(
            File.join(target_dir, File.basename(page)),
            "#{front_matter}---\n\n#{render_page(page)}"
          )
        end

        write_special('Home', target_dir)
        write_special('_Footer', target_dir)

        write_redirects(meta, target_dir)
        write_assets(target_dir)
      end

      private

      #: (String, String) -> void
      def rm_dir_glob(target_dir, pattern)
        FileUtils.rm_f(Dir.glob(File.join(target_dir, pattern)))
      end

      #: () -> Array[String]
      def collect_pages
        result = [] #: Array[String]
        @repo.head.target.tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob

          path = root.empty? ? entry[:name] : "#{root}/#{entry[:name]}"
          next unless path.end_with?('.md')

          slug = File.basename(path, '.md')
          next if @ungenerated_pages.include?(slug)

          result << path
        end
        result.sort
      end

      public

      #: (String) -> Rugged::tree_entry?
      def tree_entry(path)
        @repo.head.target.tree[path]
      end

      #: (String) -> String
      def text_for(name)
        entry = tree_entry(name)
        return '' unless entry

        @repo.lookup(entry[:oid]).content.force_encoding(Encoding::UTF_8)
      end

      #: (String) -> Hash[Symbol, Rugged::Commit?]
      def commit_bounds_for(path)
        path = path.b
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
        return nil if from_ref.nil? || from_ref == @head

        prev_commit = rev_parse(from_ref)
        return nil unless prev_commit

        prev_commit.diff(@repo.head.target)
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

      # Returns the file paths this page was renamed from, most recent first,
      # based on git rename detection across history.
      #: (String) -> Array[String]
      def rename_history_for(path)
        renames = rename_deltas #: Hash[String, String]
        result = [] #: Array[String]
        current = path.b
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
      #: () -> Hash[String, String]
      def rename_deltas
        @rename_deltas ||= begin
          map = {} #: Hash[String, String]
          @repo.walk('HEAD').each do |commit|
            next if commit.parents.empty?

            diff = commit.diff(commit.parents.first)
            diff.find_similar!(renames: true)
            diff.deltas.each do |delta|
              next unless delta.status == :renamed

              # keep the earliest predecessor for each target (walked from HEAD,
              # so first seen wins). Byte-compare paths like touched? does,
              # because rugged hands back ASCII-8BIT path strings.
              child = delta.old_file[:path].b
              parent = delta.new_file[:path].b
              map[child] ||= parent
            end
          end
          map
        end
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
        if parents.empty?
          # The root commit touches exactly the paths it introduced.
          return !commit.tree[path].nil?
        end

        commit.diff(parents.first).deltas.any? do |delta|
          delta.new_file[:path].b == path.b || delta.old_file[:path].b == path.b
        end
      end

      # The wiki repository is flat: all pages live at the repository root,
      # so a single tree lookup resolves the path.

      #: (String, ?Hash[String, meta_row]) -> String
      def article_front_matter(page_name, meta = {})
        slug = File.basename(page_name, '.md')
        row = meta[slug]
        bounds = commit_bounds_for(page_name)
        last = bounds[:latest]
        first = bounds[:earliest]
        author = if row
                   row[:author]
                 elsif last
                   last.author[:name]
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

      #: (String, String) -> void
      def write_special(name, target_dir)
        file_name = "#{name}.md"
        return unless tree_entry(file_name)

        front_matter = {
          'kind' => 'special',
          'title' => title_for(name),
          'slug' => name,
          'language' => 'en'
        }.to_yaml
        File.write(
          File.join(target_dir, file_name),
          "#{front_matter}---\n\n#{render_page(file_name)}"
        )
      end

      # Copies image attachments next to the pages so Astro can resolve
      # relative image references ([[readme.png]] etc.).
      #: (String) -> void
      def write_assets(target_dir)
        image_extensions = %w[.png .jpg .jpeg .gif .webp .svg]
        @repo.head.target.tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob

          path = root.empty? ? entry[:name] : "#{root}/#{entry[:name]}"
          next unless image_extensions.include?(File.extname(path).downcase)

          destination = File.join(target_dir, path)
          FileUtils.mkdir_p(File.dirname(destination))
          File.binwrite(destination, @repo.lookup(entry[:oid]).content)
        end
      end

      #: (Hash[String, meta_row], String) -> void
      def write_redirects(meta, target_dir)
        meta.each do |target_slug, row|
          row[:aliases].each do |title|
            alias_slug = Slugs.for_title(title)
            front_matter = {
              'kind' => 'redirect',
              'title' => title,
              'slug' => alias_slug,
              'target_slug' => target_slug,
              'language' => row[:language]
            }.to_yaml
            File.write(File.join(target_dir, "#{alias_slug}.md"), "#{front_matter}---\n\n")
          end
        end
      end
    end
  end
end
