# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Consistent title ↔ slug conversion shared across the suite.
      module Slugs
        # Map any whitespace punctuation to single hyphens.
        #: (String) -> String
        def self.for_title(title)
          out = title.strip
          out = out.gsub(/[\x00-\x20[:space:]]+/, '-')
          out = out.tr('_', '-')
          out = out.gsub(/-+/, '-')
          out.gsub(/\A-|-\z/, '')
        end

        #: (String) -> String
        def self.title_for(slug) = slug.tr('-', ' ')
      end
    end
  end
end
