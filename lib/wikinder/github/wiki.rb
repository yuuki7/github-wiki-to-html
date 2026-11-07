# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'gollum-lib'
require 'nokogiri'
require 'pathname'
require 'uri'

# @type var render_markdown: ^(String) -> String
render_markdown = proc do |markdown|
  Commonmarker.to_html(
    markdown,
    options: {
      render: {
        unsafe: true
      },
      extension: {
        autolink: true,
        footnotes: true,
        math_code: true,
        math_dollars: true,
        strikethrough: true,
        table: true,
        tagfilter: false,
        tasklist: true
      }
    }
  )
end

# Makes Commonmarker the only Markdown renderer for Gollum.
GitHub::Markup::Markdown::MARKDOWN_GEMS.replace('commonmarker' => render_markdown)

module Wikinder
  module GitHub
    # Represents a GitHub Wiki.
    class Wiki
      # Pages not generated.
      UNGENERATED_PAGE_SLUGS = %w[Home README LICENSE META].freeze #: Array[String]

      # Pages not listed on the home page.
      UNLISTED_PAGE_SLUGS = %w[Wikinder Wikinder-Japan].freeze #: Array[String]

      # @rbs @wiki: Gollum::Wiki
      # @rbs @url_base: String

      # Creates a new GitHub Wiki instance.
      #
      # @param path [String] Path to the wiki repository.
      # @param url_base [String] Base URL for page links.
      #: (String, url_base: String) -> void
      def initialize(path, url_base:)
        @wiki = Gollum::Wiki.new(
          path,
          {
            allow_editing: false,
            filter_chain: %i[Tags TOC Render],
            hyphened_tag_lookup: true,
            universal_toc: true
          }
        )
        @url_base = url_base
      end

      # Returns data for every generated page.
      #: () -> Array[{ title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, wiki_url: String, listed: bool }]
      def pages_data
        @wiki.pages
             .select { |page| page.format == :markdown }
             .reject { |page| UNGENERATED_PAGE_SLUGS.include?(page.filename_stripped) }
             .map { |page| page_data(page) }
      end

      # Returns site-wide data.
      #: () -> { name: String, home: String, footer: String }
      def site_data
        home = @wiki.page('Home')
        {
          name: 'Wikinder',
          home: postprocess_html(home.formatted_data),
          footer: home.footer.formatted_data
        }
      end

      private

      # Returns the data for a single page.
      #: (Gollum::Page) -> { title: String, slug: String, html: String, toc: String, creation_date: String, modified_date: String, author: String, wiki_url: String, listed: bool }
      def page_data(page)
        # Fetch the full history; versions are newest first.
        versions = page.versions({ limit: 0, follow: true })
        oldest = versions.last
        newest = versions.first
        slug = page.filename_stripped

        {
          title: page.title.tr('-', ' '),
          slug: slug,
          html: postprocess_html(page.formatted_data),
          toc: page.toc_data,
          creation_date: oldest.authored_date.utc.iso8601,
          modified_date: newest.authored_date.utc.iso8601,
          author: oldest.author.name,
          wiki_url: "#{@url_base}/#{URI::DEFAULT_PARSER.escape(slug)}",
          listed: !UNLISTED_PAGE_SLUGS.include?(slug)
        }
      end

      # Corrects internal links to match page URLs.
      #: (String) -> String
      def postprocess_html(html)
        dom = Nokogiri::HTML5.fragment(html)
        dom.css('a.internal').each do |anchor|
          uri = URI(anchor['href'])
          uri.path = normalize_link_path(uri.path.to_s)
          anchor['href'] = uri.to_s
        end
        dom.to_html
      end

      # Strips the extension and rewrites encoded spaces to hyphens.
      #: (String) -> String
      def normalize_link_path(path)
        Pathname(path).sub_ext('').to_s.gsub('%20', '-')
      end
    end
  end
end
