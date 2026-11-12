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
      # @rbs @ignore_meta: bool

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] unlisted_pages/ungenerated_pages Sets.
      # @param options[:ignore_meta] Ignore committed META.md and derive
      #   authorship metadata from git history instead. Used for testing.
      #: (String | Pathname, ?Hash[Symbol, Array[String] | Set[String] | bool]) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        @ungenerated_pages = Array(options[:ungenerated_pages] || []).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
        @ignore_meta = options[:ignore_meta] == true
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
        meta = Meta.sync!(self, pages, meta_path, ignore_meta: @ignore_meta)

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
        @commit_bounds ||= {} #: Hash[String, Hash[Symbol, Rugged::Commit?]]
        return @commit_bounds[path] if @commit_bounds.key?(path)

        earliest = nil #: Rugged::Commit?
        latest = nil #: Rugged::Commit?
        @repo.walk('HEAD').each do |commit|
          next unless touched?(commit, path)

          time = commit.time
          if earliest.nil? || time < earliest.time
            earliest = commit
          end
          if latest.nil? || time > latest.time
            latest = commit
          end
        end
        @commit_bounds[path] = { earliest: earliest, latest: latest }
      end

      # Returns the file paths this page was renamed from, most recent first,
      # based on git rename detection across history.
      #: (String) -> Array[String]
      def rename_history_for(path)
        matches = [] #: Array[String]
        @repo.walk('HEAD').each do |commit|
          next if commit.parents.empty?

          diff = commit.diff(commit.parents.first)
          diff.find_similar!(renames: true)
          diff.deltas.each do |delta|
            next unless delta.status == :renamed
            next unless delta.old_file[:path].b == path.b

            matches << delta.new_file[:path] # commit.diff(parent) reports: old_file = this commit, new_file = parent
          end
        end
        matches
      end

      private

      #: (String) -> String
      def render_page(name)
        Tags.render(text_for(name))
      end

      # Computes the bounds of commits touching a path over the full history.
      # Bounds are min/max by commit time; walk order does not matter.
      #: (String) -> String
      def author_for(path)
        (commit = commit_bounds_for(path)[:latest]) ? commit.author[:name] || 'unknown' : 'unknown'
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
      #: () -> Hash[String, meta_row]
      def parse_meta
        return {} if @ignore_meta

        path = 'META.md'
        entry = tree_entry(path)
        return {} unless entry

        body = @repo.lookup(entry[:oid]).content.force_encoding(Encoding::UTF_8)
        result = {} #: Hash[String, meta_row]
        body.each_line.with_index do |line, i|
          next if i < 2

          row = line.chomp
          next unless row.start_with?('|') && row.end_with?('|')

          cells = Array(row.split('|', -1)[1..-2]).map(&:strip)
          next if cells.length < 6

          item_title = cells[0]
          title_match = item_title.match(/\[\[([^\]]+)\]\]/)
          next unless title_match

          title = title_match[1].strip
          slug = Slugs.for_title(title)
          result[slug] = {
            author: cells[1],
            creation_date: cells[2],
            modified_date: cells[3],
            language: cells[4],
            aliases: cells[5].split('<br>').map(&:strip).reject(&:empty?)
          }
        end
        result
      end

      #: (String, ?Hash[String, Hash[Symbol, untyped]]) -> String
      def article_front_matter(page_name, meta = {})
        slug = File.basename(page_name, '.md')
        row = meta[slug]
        bounds = commit_bounds_for(page_name)
        last = bounds[:latest]
        first = bounds[:earliest]
        author = row ? row[:author] : (last ? last.author[:name] : 'unknown')
        creation_date = row ? row[:creation_date] : (first ? first.time.utc.iso8601 : 'unknown')
        modified_date = row ? row[:modified_date] : (last ? last.time.utc.iso8601 : 'unknown')
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

      #: (Hash[String, Hash[Symbol, untyped]], String) -> void
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
