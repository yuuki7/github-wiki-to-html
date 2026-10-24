# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'

GitHub::Markup::Markdown::MARKDOWN_GEMS.clear
GitHub::Markup::Markdown::MARKDOWN_GEMS['commonmarker'] = proc do |markdown|
  Commonmarker.to_html(markdown)
end

# Converts GitHub Wiki into HTML
module GitHubWikiToHTML
  # Represents GitHub Wiki
  class Wiki
    # @rbs @wiki: Gollum::Wiki

    #: (String) -> void
    def initialize(path)
      @wiki = Gollum::Wiki.new(path)
    end

    #: () -> String
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

  #: (String) -> Wiki
  def self.new(...)
    Wiki.new(...)
  end
end
