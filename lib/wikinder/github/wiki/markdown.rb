# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'nokogiri'
require 'uri'

module Wikinder
  module GitHub
    class Wiki
      # Controls the Markdown renderer shared by pages.
      module Markdown
        # @rbs self.@installed: bool

        # CommonMarker options for rendering wiki markdown.
        OPTIONS = {
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
        }.freeze #: commonmarker_options

        # Gollum wiki configuration options.
        GOLLUM_OPTIONS = {
          allow_editing: false,
          filter_chain: %i[Tags TOC Render],
          hyphened_tag_lookup: true,
          universal_toc: true
        }.freeze #: gollum_wiki_options

        # Makes CommonMarker the only renderer for Gollum.
        # Replaces defaults so wiki and rendered HTML stay consistent.
        #: () -> void
        def self.install!
          return if @installed

          # Wrap CommonMarker with the project's GFM options.
          # @type var render_markdown: ^(String) -> String
          render_markdown = proc do |markdown|
            Commonmarker.to_html(markdown, options: OPTIONS)
          end

          ::GitHub::Markup::Markdown::MARKDOWN_GEMS.replace('commonmarker' => render_markdown)
          @installed = true
        end

        # Corrects internal links to match page URLs.
        # Rewrites wiki internal links under the site base.
        #: (String) -> String
        def self.postprocess_html(html)
          dom = Nokogiri::HTML5.fragment(html)

          # Normalize internal links for the site build.
          dom.css('a.internal').each do |anchor|
            uri = URI(anchor['href'])
            uri.path = normalize_link_path(uri.path.to_s)
            anchor['href'] = uri.to_s
          end
          dom.to_html
        end

        # Strips the extension and rewrites encoded spaces to hyphens.
        # Keeps page URLs stable across wiki and site encodings.
        #: (String) -> String
        def self.normalize_link_path(path) = Pathname(path).sub_ext('').to_s.gsub('%20', '-')
      end
    end
  end
end
