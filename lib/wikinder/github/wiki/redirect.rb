# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      # Builds redirect pages from aliased page names.
      class Redirect
        # Writes one redirect page per alias.
        # Each redirect carries its slug as the file name and the alias title.
        #: (Array[Gollum::Page], Hash[String, Meta::Row], target_dir: String) -> void
        def self.write!(pages, meta_rows, target_dir:)
          used = pages.to_set { it.filename_stripped.downcase }
          pages.each { |page| write_one!(page, meta_rows, used, target_dir:) }
        end

        # Writes redirects for one page's aliases.
        #: (Gollum::Page, Hash[String, Meta::Row], Set[String], target_dir: String) -> void
        def self.write_one!(page, meta_rows, used, target_dir:)
          target_slug = page.filename_stripped
          meta_rows.fetch(target_slug).aliases.each do |title|
            options = { alias_title: title, target_slug:, meta_rows:, used:, target_dir: } #: write_redirect_options
            write_redirect(options)
          end
        end

        # Writes one redirect if its slug is free.
        # Strips characters that would break URL syntax. Keeps the rest.
        #: (write_redirect_options) -> void
        def self.write_redirect(options)
          slug = options[:alias_title].tr(' ', '-')
          return if slug.empty?

          used = options[:used]
          return unless used.add?(slug.downcase)

          Page.write_redirect!(
            { alias_title: options[:alias_title], alias_slug: slug,
              target_slug: options[:target_slug], language: options[:meta_rows][options[:target_slug]].language },
            target_dir: options[:target_dir]
          )
        end
        private_class_method :write_one!, :write_redirect
      end
    end
  end
end
