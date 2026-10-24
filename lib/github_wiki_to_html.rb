# frozen_string_literal: true

require 'gollum-lib'
require 'json'

::GitHub::Markup::Markdown::MARKDOWN_GEMS.clear
::GitHub::Markup::Markdown::MARKDOWN_GEMS['commonmarker'] = proc do |markdown|
  ::Commonmarker.to_html(markdown)
end

module GitHubWikiToHTML
  class Wiki
    def initialize(path)
      @wiki = ::Gollum::Wiki.new(path)
    end

    def to_json
      JSON.pretty_generate(
        @wiki.pages.map do |page|
          {
            title: page.title.tr('-', ' '),
            slug: page.filename_stripped,
            html: page.formatted_data,
          }
        end
      )
    end
  end

  def self.new(*args)
    Wiki.new(*args)
  end
end
