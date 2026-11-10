# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'wiki/markdown'
require_relative 'wiki/page'
require_relative 'wiki/redirect'
require_relative 'wiki/meta/row'
require_relative 'wiki/meta'
require 'fileutils'

module Wikinder
  module GitHub
    # Represents the Wikinder GitHub Wiki.
    #
    # Wraps Gollum::Wiki to give access to the wiki's pages and metadata.
    # It can export the wiki as GFM Markdown content for the site generator.
    class Wiki
      # @rbs @wiki: Gollum::Wiki
      # @rbs @wiki_path: Pathname
      # @rbs @meta: Meta

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # Reads the wiki's META.md page to drive authorship metadata.
      # The Markdown renderer for gollum is registered process-wide
      # once at load time of the Markdown module, not here.
      #
      # @param path [String] Path to the wiki repository.
      # @param options [wiki_options] Options for the wiki.
      # @param options[:ungenerated_pages] Pages not generated.
      # @param options[:unlisted_pages] Pages not listed on the home page.
      #: (String, ?wiki_options) -> void
      def initialize(path, options = {})
        @wiki_path = Pathname(path).expand_path
        @wiki = Gollum::Wiki.new(@wiki_path.to_s, Markdown::GOLLUM_OPTIONS)
        @ungenerated_pages = (options[:ungenerated_pages] || Set[]).freeze
        @unlisted_pages = (options[:unlisted_pages] || Set[]).freeze
        @head = @wiki.repo.head.commit.id
        @meta = Meta.new(
          wiki: @wiki,
          meta_path: @wiki_path.join('META.md'),
          head: @head,
          prev_head: options[:prev_head],
          ignore_meta: options[:ignore_meta] || false
        )
      end

      # Writes the full content tree to target_dir.
      # Syncs META first so each page reads stable authorship.
      # Slugs used as file names carry over to routes unchanged.
      #: (String) -> void
      def build(target_dir)
        FileUtils.rm_rf(target_dir)
        FileUtils.mkdir_p(target_dir)
        pages = collect_pages
        @meta.sync!(pages)
        write_pages(pages, target_dir)
        Redirect.write!(pages, @meta.rows, target_dir:)
        write_special_pages(target_dir)
      end

      private

      # Returns visible Markdown pages, excluding generated ones.
      #: () -> Array[Gollum::Page]
      def collect_pages
        @wiki.pages
             .select { |page| page.format == :markdown && !@ungenerated_pages.include?(page.filename_stripped) }
      end

      # Writes one GFM Markdown file per page.
      #: (Array[Gollum::Page], String) -> void
      def write_pages(pages, target_dir)
        pages.each do |page|
          Page.write!(
            page:,
            meta: @meta.rows.fetch(page.filename_stripped),
            unlisted_pages: @unlisted_pages,
            target_dir:
          )
        end
      end

      # Writes the home page and footer special page, as ordinary files.
      #: (String) -> void
      def write_special_pages(target_dir)
        write_special_page(name: 'Home', target_dir:)
        write_special_page(name: '_Footer', target_dir:)
      end

      # Writes a special page file for a layout slot.
      #: (name: String, target_dir: String) -> void
      def write_special_page(name:, target_dir:)
        page = @wiki.page(name) or raise "#{name} page is missing"
        file_name = "#{name}.md"
        front_matter = {
          'kind' => 'special',
          'title' => Page.title(page.filename_stripped),
          'slug' => page.filename_stripped,
          'language' => @meta.detect_language(page.text_data)
        }.to_yaml
        File.write(File.join(target_dir, file_name), "#{front_matter}---\n\n#{Markdown.transpile(page)}")
      end
    end
  end
end
