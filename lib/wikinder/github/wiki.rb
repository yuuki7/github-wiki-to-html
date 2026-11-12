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
      # @rbs @earliest: Hash[String, Rugged::Commit?]

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] unlisted_pages/ungenerated_pages Sets.
      #: (String | Pathname, ?Hash[Symbol, Array[String] | Set[String]]) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        @ungenerated_pages = Array(options[:ungenerated_pages] || []).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
      end

      # Builds the entire output tree, writing Markdown files with YAML front matter.
      # Builds the entire output tree, writing Markdown files with YAML front matter.
      #: (String) -> void
      def build(target_dir)
        rm_dir_glob(target_dir, '*.md')
        FileUtils.mkdir_p(target_dir)

        pages = collect_pages
        meta = parse_meta

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

      #: (String) -> String
      def text_for(name)
        entry = tree_entry(name)
        return '' unless entry

        @repo.lookup(entry[:oid]).content.force_encoding(Encoding::UTF_8)
      end

      #: (String) -> String
      def render_page(name)
        Tags.render(text_for(name))
      end

      #: (String) -> Rugged::Commit?
      def earliest_commit_for(path)
        @earliest ||= {} #: Hash[String, Rugged::Commit?]
        return @earliest[path] if @earliest.key?(path)

        earliest = nil #: Rugged::Commit?
        # Walk commits with default (reverse chronological) order and keep
        # the oldest one that touched the file.
        @repo.walk('HEAD').each do |commit|
          if touched?(commit, path)
            earliest = commit
          elsif earliest
            break
          end
        end
        @earliest[path] = earliest
      end

      #: () -> String
      def head_commit_date = @repo.head.target.time.utc.iso8601

      #: () -> String
      def head_author = @repo.head.target.author[:name] || 'unknown'

      #: (String) -> String
      def detect_language(text) = Language.call(text)

      #: (Rugged::Commit, String) -> bool
      def touched?(commit, path)
        parents = commit.parents
        return true if parents.empty?

        commit.diff(parents.first).deltas.any? do |delta|
          delta.new_file[:path] == path || delta.old_file[:path] == path
        end
      end

      # The wiki repository is flat: all pages live at the repository root,
      # so a single tree lookup resolves the path.
      #: (String) -> Rugged::Entry?
      def tree_entry(path)
        @repo.head.target.tree[path]
      end

      #: () -> Hash[String, meta_row]
      def parse_meta
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

      #: (String, ?Hash[String, meta_row]) -> String
      def article_front_matter(page_name, meta = {})
        slug = File.basename(page_name, '.md')
        row = meta[slug]
        earliest = earliest_commit_for(page_name)
        author = row ? row[:author] : head_author
        creation_date =
          if row
            row[:creation_date]
          elsif earliest
            earliest.time.utc.iso8601
          else
            'unknown'
          end
        modified_date = row ? row[:modified_date] : head_commit_date
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
