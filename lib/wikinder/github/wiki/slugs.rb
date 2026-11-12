# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Consistent title ↔ slug conversion shared across the suite,
      # mirroring gollum's handling of page files: spaces become hyphens,
      # everything else passes through unchanged. The transform is lossy by
      # design — a literal hyphen in a title is indistinguishable from the
      # space→hyphen mapping, so title_for collapses both to spaces and no
      # round-trip is assumed.
      module Slugs
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
