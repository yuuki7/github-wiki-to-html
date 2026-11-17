# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Converts between page titles and slugs.
      #
      # The conversion mirrors gollum's handling of page files:
      # spaces become hyphens, everything else passes through
      # unchanged. The transform is lossy by design — a literal
      # hyphen in a title is indistinguishable from the
      # space→hyphen mapping — so title_for collapses both to
      # spaces and no round-trip is assumed.
      module Slugs
        #: (String) -> String
        def self.for_title(title)
          title.strip.gsub(' ', '-')
        end

        #: (String) -> String
        def self.title_for(slug) = slug.tr('-', ' ')

        # Returns true when +slug+ is usable as the path segment of
        # a generated page or redirect: no separators, no parent
        # references, never hidden or empty, and short enough for a
        # filesystem's name length limit. Such names can still
        # appear as titles; they just may not escape the output
        # directory or collapse onto site routes.
        #: (String) -> bool
        def self.safe?(slug)
          return false if slug.empty?
          return false if ['.', '..'].include?(slug)
          return false if slug.include?('/') || slug.include?('\\')
          return false if slug.start_with?('.') # dotfiles are never wiki pages
          # Filesystems cap the length of any single path component
          # (typically at 255 bytes); the cap here leaves room for
          # the .md extension on top of the slug.
          return false if slug.bytesize > 252

          true
        end
      end
    end
  end
end
