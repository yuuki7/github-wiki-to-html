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
      # @rbs @wiki: Gollum::Wiki
      # @rbs type page = { title: String, slug: String, html: String, toc: String? }
      # @rbs type site = { footer: String? }

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

      # Returns all pages data.
      #
      # @return [Array[page]] An array of page data.
      #: () -> Array[page]
      def pages_data
        @wiki.pages.select { |p| p.format == :markdown }.map do |page|
          {
            title: page.title.tr('-', ' '),
            slug: page.filename_stripped,
            html: postprocess_html(page.formatted_data),
            toc: page.toc_data,
            creation_date: page.versions.last&.authored_date&.iso8601
          }
        end
      end

      # Returns site data.
      #
      # @return [site] A hash containing site-wide data.
      #: () -> site
      def site_data
        {
          footer: @wiki.page('Home')&.footer&.formatted_data
        }
      end

      private

      #: (String) -> String
      def postprocess_html(html)
        dom = Nokogiri::HTML5.fragment(html)
        dom.css('a.internal').each do |a|
          uri = URI(a['href'])
          uri.path = Pathname(uri.path).sub_ext('').to_s
          uri.path = uri.path.gsub('%20', '-')
          a['href'] = uri.to_s
        end
        dom.to_html
      end
    end
  end
end
