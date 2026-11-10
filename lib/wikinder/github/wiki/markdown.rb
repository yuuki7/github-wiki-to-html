# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'code_regions'
require_relative 'ast_tags'
require 'gollum-lib'
require 'commonmarker'
require 'uri'

module Wikinder
  module GitHub
    class Wiki
      # Converts GitHub Wiki Markdown to standard GFM Markdown.
      #
      # Uses gollum-lib to resolve Wiki markup (internal links, anchors,
      # images, file links, escapes, and code regions). The passthrough
      # renderer keeps the document as Markdown so the SSG can render it
      # like any other content. Code regions stay untouched so tags
      # written inside them survive verbatim.
      module Markdown
        # @rbs self.@installed: bool

        # Gollum options for rendering the wiki.
        GOLLUM_OPTIONS = {
          allow_editing: false,
          filter_chain: %i[AstTags Render],
          hyphened_tag_lookup: true,
          universal_toc: true
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

        # Renders a wiki page as GFM Markdown.
        # Tags are resolved in place; the SSG renders the result.
        #: (Gollum::Page) -> String
        def self.transpile(page)
          markdown = page.formatted_data.dup
          normalize_math(markdown)
          markdown
        end

        # Rewrites math code spans ($`...`$) to math dollars ($...$).
        # The SSG handles GFM dollars; code fences stay untouched.
        #: (String) -> String
        def self.normalize_math(markdown)
          return markdown if markdown.empty?

          ranges = math_code_ranges(markdown)
          ranges.reverse_each do |start, finish|
            math_body = markdown[(start...finish)]&.slice(2..-3).to_s
            markdown[(start...finish)] = "$#{math_body}$"
          end
          markdown
        end

        # Byte ranges of inline math code nodes ($`...`$).
        #: (String) -> Array[[Integer, Integer]]
        def self.math_code_ranges(markdown)
          doc = Commonmarker.parse(markdown, options: { extension: { math_code: true, math_dollars: true } })
          ranges = [] #: Array[[Integer, Integer]]
          offset_of_line = byte_offsets_by_line(markdown)
          doc.walk do |node|
            next unless node.type == :math

            sp = node.source_position
            start = offset_of_line[sp[:start_line] - 1] + sp[:start_column] - 1
            finish = offset_of_line[sp[:end_line] - 1] + sp[:end_column]
            ranges << [start, finish] if math_code_span?(markdown[start...finish])
          end
          ranges
        end

        # Returns true when the span uses math code, i.e. $`...`$.
        #: (String?) -> bool
        def self.math_code_span?(span)
          span ? span.start_with?('$`') && span.end_with?('`$') : false
        end

        # Returns byte offsets of the start of each line.
        #: (String) -> Array[Integer]
        def self.byte_offsets_by_line(markdown)
          offset = 0
          lines = [] #: Array[Integer]
          markdown.each_line do |line|
            lines << offset
            offset += line.bytesize
          end
          lines
        end
      end
    end
  end
end
