# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'verbatim_code'
require_relative 'gfm_spans'
require_relative 'ast_tags'
require 'gollum-lib'

module Wikinder
  module GitHub
    class Wiki
      # Converts GitHub Wiki Markdown to standard GFM Markdown.
      #
      # Wikinder relies on gollum-lib for its Markdown semantics
      # (wiki tags, page lookup, link kinds). The filter chain is:
      #
      #   VerbatimCode, GfmSpans, AstTags, Render
      #
      # VerbatimCode withdraws fenced code blocks before anything else sees it.
      # GfmSpans withdraws inline code and math spans in a single AST walk and
      # preserves their literal content. AstTags resolves wiki markup. Render
      # is a passthrough, so the SSG re-renders the final GFM document.
      module Markdown
        # @rbs self.@installed: bool

        GOLLUM_OPTIONS = {
          allow_editing: false,
          filter_chain: %i[VerbatimCode GfmSpans AstTags Render],
          hyphened_tag_lookup: true
        }.freeze #: gollum_wiki_options

        # Makes gollum-lib emit Markdown instead of HTML.
        # Registers the official renderer hook; nothing is patched.
        #: () -> void
        def self.install!
          return if @installed

          ::Gollum::Markup.register(
            :markdown, 'Markdown',
            extensions: %w[md mkd mkdn mdown markdown],
            render: proc { |data| data }
          )
          @installed = true
        end

        # Registering a renderer is process-wide; done once at load time
        # so constructing a Wiki has no hidden side effects.
        install!

        # Renders a page as GFM Markdown.
        # Tags, math and code were handled by the filter chain.
        #: (Gollum::Page) -> String
        def self.transpile(page) = page.formatted_data.dup
      end
    end
  end
end
