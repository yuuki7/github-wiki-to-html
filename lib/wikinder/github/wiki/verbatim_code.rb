# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'

module Gollum
  class Filter
    # Restores fenced code blocks verbatim, in Gollum Markdown form.
    #
    # Gollum's Code filter renders blocks to highlighted HTML, which the
    # passthrough renderer cannot reapply. This subclass keeps the GFM
    # fence so the SSG renders code like any other Markdown content.
    class VerbatimCode < Code
      #: (String) -> String
      def process(data)
        return data if @map.empty?

        data.gsub(/#{open_pattern}[a-f0-9]+#{close_pattern}/) do |id|
          spec = @map[id]
          spec ? fence_block(spec[:lang], spec[:code], spec[:indent]) : id
        end
      end

      private

      # Builds the GFM fenced code block for a cached block.
      #: (String?, String, String?) -> String
      def fence_block(lang, code, indent)
        indent ||= ''
        "#{indent}```#{lang}\n#{indent}#{code}\n#{indent}```"
      end
    end
  end
end
