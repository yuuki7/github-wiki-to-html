# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'wiki/markdown'
require_relative 'wiki/page'
require_relative 'wiki/redirect'
require_relative 'wiki/meta'

module Wikinder
  module GitHub
    # Represents a GitHub Wiki.
    # Loads pages with Gollum and serves META as the source for authorship.
    class Wiki
      # Pages not generated.
      UNGENERATED_PAGES = Set['Home', 'README', 'LICENSE', 'META'].freeze #: Set[String]

      # Pages not listed on the home page.
      UNLISTED_PAGES = Set['Wikinder', 'Wikinder-Japan'].freeze #: Set[String]

      # @rbs @wiki: Gollum::Wiki
      # @rbs @wiki_url: URI::Generic
      # @rbs @head: String
      # @rbs @wiki_path: Pathname
      # @rbs @meta: Meta

      # Creates a new instance for a wiki repository.
      #
      # @param path [String] Path to the wiki repository.
      # @param options [wiki_options] Options for the wiki.
      # Installs the renderer and loads META rows at start.
      #: (String, ?wiki_options) -> void
      def initialize(path, options = {})
        @wiki_path = Pathname(path).expand_path
        Markdown.install!
        @wiki = Gollum::Wiki.new(@wiki_path.to_s, Markdown::GOLLUM_OPTIONS)
        @wiki_url = URI(options.fetch(:wiki_url))
        @head = @wiki.repo.head.commit.id
        @meta = Meta.new(
          wiki: @wiki,
          meta_path: @wiki_path.join('META.md'),
          head: @head,
          prev_head: options[:prev_head],
          ignore_meta: options[:ignore_meta] || false
        )
      end

      # Returns data for every generated page.
      # Syncs META first so each page reads stable authorship.
      #: () -> Array[page_entry | redirect_entry]
      def pages_data
        # Collect the visible markdown pages, then merge in the redirects.
        pages = @wiki.pages
                     .select { |page| page.format == :markdown && !UNGENERATED_PAGES.include?(page.filename_stripped) }
        @meta.sync!(pages)

        # Assemble full entries from the freshly synced META rows.
        canonical = pages.map do |page|
          Page.build(
            page:,
            meta: @meta.rows.fetch(page.filename_stripped),
            wiki_url: @wiki_url,
            unlisted_pages: UNLISTED_PAGES
          )
        end
        canonical + Redirect.entries(pages, @meta.rows)
      end

      # Returns site-wide data.
      # Exposes head so the next run can update incrementally.
      #: () -> { name: String, home: String, footer: String, head: String, language: String }
      def site_data
        home = @wiki.page('Home') or raise 'Home page is missing'
        footer = home.footer or raise 'Footer page is missing'

        {
          name: 'Wikinder',
          home: Markdown.postprocess_html(home.formatted_data),
          footer: footer.formatted_data,
          head: @head,
          language: @meta.detect_language(home.text_data)
        }
      end
    end
  end
end
