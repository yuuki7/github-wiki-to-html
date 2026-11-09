# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Builds redirect entries from aliased page names.
      class Redirect
        # Returns redirect entries mixed with pages.
        # Each entry holds its slug and display title.
        #: (Array[Gollum::Page], Hash[String, Meta::Row]) -> Array[redirect_entry]
        def self.entries(pages, meta_rows)
          used = pages.to_set { it.filename_stripped.downcase }

          pages.flat_map do |page|
            target_slug = page.filename_stripped
            meta_rows.fetch(target_slug).aliases.filter_map do |title|
              # Redirects match the slug shape used by canonical pages.
              slug = title.tr(' ', '-')
              next if slug.empty? || !used.add?(slug.downcase)

              { slug:, title:, redirect: true, target_slug: }
            end
          end
        end
      end
    end
  end
end
