# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'gollum-lib'
require 'json'
require 'nokogiri'
require 'pathname'
require 'uri'

# @type var markdown_proc: ^(String) -> String
markdown_proc = proc do |markdown|
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

GitHub::Markup::Markdown::MARKDOWN_GEMS.clear
GitHub::Markup::Markdown::MARKDOWN_GEMS['commonmarker'] = markdown_proc

module Wikinder
  module GitHub
    # Represents GitHub Wiki.
    class Wiki
      # Pages the site consumes itself and that get no generated page of their own.
      UNGENERATED_PAGE_SLUGS = %w[Home README LICENSE META].freeze

      # Pages that get a generated page, but are left out of the recently created pages
      # list.
      UNLISTED_PAGE_SLUGS = %w[Wikinder Wikinder-Japan].freeze

      # @rbs @wiki: Gollum::Wiki

      # Creates a new GitHub Wiki instance.
      #
      # @param path [String] The path to the GitHub Wiki repository.
      #: (String) -> void
      def initialize(path)
        @wiki = Gollum::Wiki.new(
          path,
          {
            allow_editing: false,
            filter_chain: %i[Tags TOC Render],
            hyphened_tag_lookup: true,
            universal_toc: true
          }
        )
      end

      # Returns pages data.
      #
      # @return [Array] An array of page data.
      #: () -> Array[{ title: String, slug: String, html: String, toc: String?, creation_date: String?, listed: bool }]
      def pages_data
        @wiki.pages
             .select { |p| p.format == :markdown }
             .reject { |p| UNGENERATED_PAGE_SLUGS.include?(p.filename_stripped) }
             .map do |page|
          {
            title: page.title.tr('-', ' '),
            slug: page.filename_stripped,
            html: postprocess_html(page.formatted_data),
            toc: page.toc_data,
            creation_date: page.versions.last&.authored_date&.iso8601,
            listed: !UNLISTED_PAGE_SLUGS.include?(page.filename_stripped)
          }
        end
      end

      # Returns site data.
      #
      # @return [Hash] A hash containing site-wide data.
      #: () -> { name: String, home: String?, footer: String? }
      def site_data
        home = @wiki.page('Home')
        {
          name: 'Wikinder',
          home: home ? postprocess_html(home.formatted_data) : nil,
          footer: home&.footer&.formatted_data
        }
      end

      private

      #: (String) -> String
      def postprocess_html(html)
        dom = Nokogiri::HTML5.fragment(html)
        dom.css('a.internal').each do |a|
          uri = URI(a['href'])
          uri.path = normalize_link_path(uri.path.to_s)
          a['href'] = uri.to_s
        end
        dom.to_html
      end

      # Strips the file extension from a link path and un-escapes percent-encoded spaces
      # to hyphens, matching the site's slugs.
      #: (String) -> String
      def normalize_link_path(path)
        Pathname(path).sub_ext('').to_s.gsub('%20', '-')
      end
    end
  end
end
