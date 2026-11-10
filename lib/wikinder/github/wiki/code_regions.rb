# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'

module Wikinder
  module GitHub
    class Wiki
      # Byte ranges of code regions in a Markdown document.
      #
      # AST-based detection (commonmarker), not regex: fenced blocks,
      # indented blocks, and inline code are all covered uniformly.
      module CodeRegions
        # Returns byte ranges of code regions in src.
        #: (String) -> Array[Range[Integer]]
        def self.code_ranges(src)
          offset_of_line = offset_of_each_line(src)
          ranges = [] #: Array[Range[Integer]]
          Commonmarker.parse(src).walk do |node|
            next unless %w[code code_block].include?(node.type.to_s)

            sp = node.source_position
            first = byte_offset(offset_of_line, sp[:start_line], sp[:start_column])
            last = byte_offset(offset_of_line, sp[:end_line], sp[:end_column])
            ranges << (first...last)
          end
          ranges.sort_by(&:begin)
        end

        # Applies `block` to non-code regions, keeping code regions verbatim.
        # Yields segment and a Boolean code flag.
        #: (String) { (String, bool) -> String } -> String
        def self.process_regions(src)
          ranges = code_ranges(src)
          return yield(src, false) if ranges.empty?

          out = +''
          last = 0
          ranges.each do |range|
            out << yield(src.byteslice(last...range.begin) || '', false)
            out << yield(src.byteslice(range) || '', true)
            last = range.end
          end
          out << yield(src.byteslice(last..) || '', false)
          out
        end

        #: (String) -> Array[Integer]
        def self.offset_of_each_line(src)
          offset = 0
          lines = [] #: Array[Integer]
          src.each_line do |line|
            lines << offset
            offset += line.bytesize
          end
          lines
        end
        private_class_method :offset_of_each_line

        #: (Array[Integer], Integer, Integer) -> Integer
        def self.byte_offset(offset_of_line, line, column)
          offset_of_line[line - 1] + column - 1
        end
        private_class_method :byte_offset
      end
    end
  end
end
