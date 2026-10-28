# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'

# @type var markdown_proc: ^(String) -> String
markdown_proc = proc do |markdown|
  Commonmarker.to_html(
    markdown,
    options: {
      render: {
        unsafe: true
      },
      extension: {
        # strikethrough: true,
        # tagfilter: true,
        # table: true,
        # autolink: true,
        # tasklist: true,
        footnotes: true
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

      # Creates a new GitHub Wiki instance.
      #
      # @param path [String] The path to the GitHub Wiki repository.
      #: (String) -> void
      def initialize(path)
        @wiki = Gollum::Wiki.new(
          path,
          {
            hyphened_tag_lookup: true,
            allow_editing: false,
            filter_chain: %i[Tags Render]
          }
        )
      end

      # Serializes all pages into JSON.
      #
      # @return [String] A JSON string containing all page data.
      #: (?(::JSON::State | nil)) -> String
      def to_json(...)
        @wiki.pages.map do |page|
          {
            title: page.title.tr('-', ' '),
            slug: page.filename_stripped,
            html: page.formatted_data
          }
        end.to_json(...)
      end
    end
  end
end
