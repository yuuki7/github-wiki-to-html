# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Consistent title ↔ slug conversion shared across the suite.
      module Slugs
        # Map ASCII spaces to hyphens, mirroring gollum's hyphened_tag_lookup
        # (path_compare): a literal site <-> filename transform, not collapsing.
        # Underscores and other punctuation pass through unchanged.
        #: (String) -> String
        def self.for_title(title)
          title.strip.gsub(' ', '-')
        end

        #: (String) -> String
        def self.title_for(slug) = slug.tr('-', ' ')
      end
    end
  end
end
