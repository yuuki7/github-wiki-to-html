# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'digest/sha1'

module Gollum
  class Filter
    # Normalizes math spans from code form to GFM dollar math.
    #
    # GitHub-style `$`...`$` is rewritten to `$...$` so the SSG renders
    # math itself. Extraction runs after code protection and before tag
    # resolution, so tags inside math bodies are not touched.
    class Math < Filter
      #: (String) -> String
      def extract(data)
        data.gsub(/\$`([\s\S]+?)`\$/) do
          body = Regexp.last_match(1) || ''
          id = "#{open_pattern}#{Digest::SHA1.hexdigest(body)}#{close_pattern}"
          @map[id] = body
          id
        end
      end

      #: (String) -> String
      def process(data)
        return data if @map.empty?

        @map.each do |id, body|
          data = data.gsub(id) { "$#{body}$" }
        end
        data
      end
    end
  end
end
