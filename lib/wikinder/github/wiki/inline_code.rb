# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'digest/sha1'

module Gollum
  class Filter
    # Extracts inline code spans so tags inside them stay literal.
    #
    # Gollum protects HTML <code> elements after rendering; the passthrough
    # renderer never renders to HTML, so protection has to happen here at
    # the text stage. Fenced blocks are handled by VerbatimCode before this.
    class InlineCode < Filter
      #: (String) -> String
      def extract(data)
        data.gsub(/(`+)([\s\S]+?)\1/) do
          span = Regexp.last_match(0) || ''
          id = "#{open_pattern}#{Digest::SHA1.hexdigest(span)}#{close_pattern}"
          @map[id] = span
          id
        end
      end

      #: (String) -> String
      def process(data)
        return data if @map.empty?

        @map.each do |id, span|
          data = data.gsub(id) { span }
        end
        data
      end
    end
  end
end
