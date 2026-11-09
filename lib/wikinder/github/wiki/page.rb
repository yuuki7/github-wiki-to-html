# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'uri'

module Wikinder
  module GitHub
    class Wiki
      # Represents one generated page.
      class Page
        # Returns a display title from a slug.
        # Turns ASCII hyphens into spaces.
        #: (String) -> String
        def self.title(slug) = slug.tr('-', ' ')

        # Returns the data for a single page.
        # Reads authorship from META rather than recomputing from history.
        #: (page: Gollum::Page, meta: Meta::Row, wiki_url: URI::Generic, unlisted_pages: Set[String]) -> page_entry
        def self.build(page:, meta:, wiki_url:, unlisted_pages:)
          slug = page.filename_stripped

          # @type var result: page_entry
          result = {
            title: title(slug),
            slug:,
            html: Markdown.postprocess_html(page.formatted_data),
            toc: page.toc_data,
            **meta.to_h,
            url_on_wiki: URI("#{wiki_url}/#{URI.encode_uri_component(slug)}"),
            listed: !unlisted_pages.include?(slug)
          }
          result
        end
      end
    end
  end
end
