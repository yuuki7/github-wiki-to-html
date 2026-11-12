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

        # Returns true when +slug+ is usable as the natural path segment of
        # a generated page or redirect: no directory separators, no parent
        # references, never hidden or empty. Such names can still appear as
        # titles, but may not emit path segments that escape the output
        # directory or collapse onto site routes.
        #: (String) -> bool
        def self.safe?(slug)
          return false if slug.empty?
          return false if ['.', '..'].include?(slug)
          return false if slug.include?('/') || slug.include?('\\')
          return false if slug.start_with?('.') # dotfiles are never wiki pages

          true
        end
      end
    end
  end
end
