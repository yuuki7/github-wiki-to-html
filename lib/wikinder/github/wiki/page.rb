# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'
require 'yaml'

module Wikinder
  module GitHub
    class Wiki
      # Represents one generated page.
      class Page
        # Returns a display title from a slug.
        # Turns ASCII hyphens into spaces.
        #: (String) -> String
        def self.title(slug) = slug.tr('-', ' ')

        # Writes the page's GFM Markdown file, with YAML front matter.
        # Reads authorship from META rather than recomputing from history.
        #: (page: Gollum::Page, meta: Meta::Row, unlisted_pages: Set[String], target_dir: String) -> String
        def self.write!(page:, meta:, unlisted_pages:, target_dir:)
          front_matter = build_front_matter(page:, meta:, unlisted_pages:)
          write_markdown(
            target_dir:,
            file_name: "#{page.filename_stripped}.md",
            front_matter:,
            body: Markdown.transpile(page)
          )
        end

        # Writes a redirect page aliased to the given target page.
        #: (redirect_front_matter, target_dir: String) -> String
        def self.write_redirect!(attrs, target_dir:)
          front_matter = build_redirect_front_matter(attrs)
          write_markdown(
            target_dir:,
            file_name: "#{attrs[:alias_slug]}.md",
            front_matter:,
            body: ''
          )
        end

        # Assembles YAML front matter for a redirect page.
        #: (redirect_front_matter) -> String
        def self.build_redirect_front_matter(attrs)
          { 'kind' => 'redirect', 'title' => attrs[:alias_title], 'slug' => attrs[:alias_slug],
            'target_slug' => attrs[:target_slug], 'language' => attrs[:language] }.to_yaml
        end

        # Assembles YAML front matter for a canonical page.
        #: (page: Gollum::Page, meta: Meta::Row, unlisted_pages: Set[String]) -> String
        def self.build_front_matter(page:, meta:, unlisted_pages:)
          slug = page.filename_stripped
          front_matter(page, meta, unlisted_pages, slug)
        end

        # Assembles YAML front matter for a canonical page.
        #: (Gollum::Page, Meta::Row, Set[String], String) -> String
        def self.front_matter(_page, meta, unlisted_pages, slug)
          base = { 'kind' => 'article', 'title' => title(slug), 'slug' => slug,
                   'author' => meta.author, 'creation_date' => meta.creation_date,
                   'modified_date' => meta.modified_date, 'language' => meta.language }
          base.merge(unlisted_pages.include?(slug) ? { 'listed' => false } : {}).to_yaml
        end

        # Writes the front matter and body as an .md file.
        #: (target_dir: String, file_name: String, front_matter: String, body: String) -> String
        def self.write_markdown(target_dir:, file_name:, front_matter:, body:)
          path = File.join(target_dir, file_name)
          body_block = body.empty? ? "---\n" : "---\n\n#{body}"
          File.write(path, "#{front_matter}#{body_block}")
          path
        end
      end
    end
  end
end
