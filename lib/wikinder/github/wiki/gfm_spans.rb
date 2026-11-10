# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'digest/sha1'
require 'commonmarker'

module Gollum
  class Filter
    # Replaces GFM inline code spans and math spans with placeholders
    # so upstream filters never see their raw content, and restores
    # them verbatim afterwards.
    #
    # Both node kinds are recognized with the same AST walk that the
    # SSG uses to render GFM, so inline code (backticks) takes
    # precedence over math according to the spec. Math delimiters in
    # code form are rewritten to dollar math, the form GFM renders
    # as math; dollar math forms are restored verbatim.
    class GfmSpans < Filter
      # Replaces inline code spans, math spans, and indented code blocks
      # with placeholders so upstream filters never see their raw content.
      # GFM indented code blocks are protected verbatim as well.
      #: (String) -> String
      def extract(data)
        return data if data.empty?

        # Collect spans as byte ranges, then rebuild by splicing pieces
        # from the end of the document backwards.
        offsets = line_offsets(data)
        spans = [] #: Array[Array[untyped]]
        Commonmarker.parse(data, options: { extension: { math_dollars: true, math_code: true } }).walk do |node|
          type = node.type.to_s
          sp   = node.source_position
          next unless %w[code code_block math].include?(type)

          first = byte_offset(offsets, sp[:start_line], sp[:start_column])
          last  = byte_offset_end(offsets, sp[:end_line], sp[:end_column])
          spans << [first, last, type, data.byteslice(first...last)]
        end
        replacements = spans.map do |first, last, type, span|
          id = "#{open_pattern}#{Digest::SHA1.hexdigest("#{type}:#{span}")}#{close_pattern}"
          @map[id] = [type, span]
          [first, last, id]
        end
        replacements.sort_by! { |first, _, _| -first }
        replacements.each do |first, last, id|
          data = (data.byteslice(0...first) || '') + id + (data.byteslice(last..) || '')
        end
        data
      end

      #: (String) -> String
      def process(data)
        return data if @map.empty?

        data.gsub(/#{open_pattern}[a-f0-9]+#{close_pattern}/) do |id|
          entry = @map[id]
          if entry.nil?
            id
          else
            type, span = entry
            type == 'math' && span.start_with?('$`') && span.end_with?('`$') ? "$#{span[2..-3]}$" : span
          end
        end
      end

      private

      #: (String) -> Array[Integer]
      def line_offsets(data)
        offset = 0
        lines = [] #: Array[Integer]
        data.each_line do |line|
          lines << offset
          offset += line.bytesize
        end
        lines
      end

      #: (Array[Integer], Integer, Integer) -> Integer
      def byte_offset(offsets, line, column)
        offsets[line - 1] + column - 1
      end

      #: (Array[Integer], Integer, Integer) -> Integer
      def byte_offset_end(offsets, line, column)
        offsets[line - 1] + column
      end
    end
  end
end
