# frozen_string_literal: true
# rbs_inline: enabled

require 'rugged'
require 'yaml'
require 'fileutils'
require 'time'
require 'whatlanguage'

require_relative 'wiki/slugs'
require_relative 'wiki/language'
require_relative 'wiki/tags'
require_relative 'wiki/history'
require_relative 'wiki/meta'

module Wikinder
  module GitHub
    # Represents the Wikinder GitHub Wiki.
    #
    # The wiki repository contains .md files; this class enumerates
    # them, rewrites wiki-specific syntax, and produces YAML front
    # matter with metadata for downstream consumers.
    #
    # GitHub Wiki is flat — pages are addressed by name only — so
    # subdirectory blobs are unsupported and ignored entirely.
    class Wiki
      # The error a build fails with on purpose: bad input, an
      # unsupported translation, an unsafe output path. Callers can
      # rescue this class to tell such failures apart from bugs and
      # library errors.
      class Error < StandardError; end

      # The file extensions of the image assets a page can embed.
      IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .svg].freeze #: Array[String]

      # One row of META.md, as Meta keeps it. Rows are values:
      # a refresh replaces a row with an updated copy instead of
      # mutating it.
      MetaRow = Data.define(
        :slug,           #: String
        :title,          #: String
        :author,         #: String
        :creation_date,  #: String
        :modified_date,  #: String
        :language,       #: String
        :aliases         #: Array[String]
      )

      # An original page: its file path and its own language.
      OriginalPage = Data.define(
        :page,     #: String
        :language  #: String
      )

      # One translation file, as read from the translations
      # directory: the original page's slug, the translation's
      # language, its optional title, its body, and whether it
      # restates a special page (Home or _Footer).
      TranslationRecord = Data.define(
        :slug,      #: String
        :language,  #: String
        :title,     #: String?
        :body,      #: String
        :special    #: bool
      )

      # @rbs @path: Pathname
      # @rbs @repo: Rugged::Repository
      # @rbs @history: History
      # @rbs @link_index: link_index?
      # @rbs @tree: Rugged::Tree
      # @rbs @ignore_meta: bool
      # @rbs @prev_head: String?
      # @rbs @site_language: String?
      # @rbs @translations_dir: String?
      # @rbs @meta_path: Pathname?
      # @rbs @meta_rows: Hash[String, MetaRow]?

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]
      attr_reader :supported_languages #: Array[String]

      # The history queries Meta builds on, delegated to History.
      # The rest of History's surface is this class's own business
      # and is reached through @history directly.

      #: (String) -> commit_bounds
      def commit_bounds_for(path) = @history.commit_bounds_for(path)

      #: (String) -> Array[String]
      def rename_history_for(path) = @history.rename_history_for(path)

      #: (String?) -> Array[String]?
      def diff_paths(from_ref) = @history.diff_paths(from_ref)

      #: (String) -> String
      def text_for(name) = @history.text_for(name)

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] Options for the build. Each key is
      #   documented below.
      # @option options [Set[String]] :ungenerated_pages Pages the
      #   build never generates as articles. The default is the set
      #   the conversion CLI passes — the site parts and repository
      #   files that are not articles — so Home and _Footer are not
      #   emitted as ordinary articles. Pass a subset (such as
      #   Set['META']) to opt out of each.
      # @option options [Set[String]] :unlisted_pages Pages kept out
      #   of the home page's list of articles.
      # @option options [Boolean] :ignore_meta Ignore committed
      #   META.md and derive authorship metadata from git history
      #   instead. Used for testing.
      # @option options [String, nil] :prev_head SHA of the commit
      #   this repo was last read at. Used for incremental META.md
      #   sync.
      # @option options [String, nil] :site_language The site's
      #   language, stamped onto special pages, whose originals
      #   belong to it. Site metadata belongs to the caller (the
      #   conversion CLI maintains it); the module never reads a
      #   site file and never detects a language for site parts.
      # @option options [Array[String]] :supported_languages The
      #   languages the site offers. Non-empty, the list declares
      #   the site's language set: the site language must belong to
      #   it, every page must exist in every language in it, and a
      #   translation directory naming any other language fails the
      #   build. Original pages may be written in any language: a
      #   page's language comes from its META row or from
      #   detection, and detection is a heuristic taken as it comes,
      #   never a ground truth to fail a build on. Empty, no set is
      #   declared: every language found is accepted, and a link to
      #   a page with no version in the reader's language points at
      #   the original.
      # @option options [String, Pathname, nil] :translations_dir
      #   Directory holding translated pages as data, one
      #   subdirectory per language
      #   (translations/<language>/<Slug>.md). The files are inputs
      #   produced elsewhere — translation is not this module's
      #   business — and their front matter's only key read is
      #   +title+ (the translated title).
      #: (String | Pathname, ?wiki_options) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        @history = History.new(@repo, @head)
        head_commit = @history.head_commit
        raise Error, 'HEAD does not name a commit' unless head_commit

        # Capture the tree once so walking / lookup during build does not
        # change mid-build (the wiki could otherwise move under a build).
        @tree = head_commit.tree
        @ungenerated_pages = Array(
          options.fetch(:ungenerated_pages) { Set['Home', 'README', 'LICENSE', 'META', '_Footer'] }
        ).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
        @ignore_meta = options[:ignore_meta] == true
        prev_head = options[:prev_head]
        @prev_head = prev_head.is_a?(String) ? prev_head : nil
        supported = options[:supported_languages] || []
        site_language = options[:site_language]
        # A supplied site language must name a language: dropping a
        # malformed value would stamp the special pages with no
        # language and let a caller error build successfully.
        # Omitting the option stays valid; the special pages then
        # carry no language, as the option documentation states.
        @site_language = if site_language.is_a?(String)
                           normalized = Language.normalize(site_language, supported:)
                           if normalized.nil?
                             raise Error, "site_language #{site_language.inspect} does not name a language"
                           end

                           normalized
                         end
        # The same rule applies to each supported language the
        # caller named: a value that names no language fails here
        # instead of being dropped from the list silently.
        supported_list = supported.map do |code|
          normalized = Language.normalize(code, supported:)
          raise Error, "supported_languages entry #{code.inspect} does not name a language" if normalized.nil?

          normalized
        end
        @supported_languages = supported_list.uniq.freeze
        # When a language set is declared, the site language must
        # belong to it: the original special pages are part of the
        # set's matrix like any other page.
        site_language_value = @site_language
        if site_language_value && !@supported_languages.empty? &&
           !@supported_languages.include?(site_language_value)
          raise Error, "site_language #{site_language_value.inspect} is not a supported language"
        end

        translations_dir = options[:translations_dir]
        @translations_dir = translations_dir ? Pathname(translations_dir.to_s).expand_path.to_s : nil
      end

      # Builds the entire output tree, writing Markdown files with YAML front matter.
      #
      # Outputs are computed in memory first and written only when
      # every one succeeded, each via a same-directory temporary
      # file renamed into place: a crash can mix old and new files,
      # but never tear an individual file. Files the new build no
      # longer produces are then removed; unrelated files stay
      # untouched.
      #: (String) -> void
      def build(target_dir)
        outputs = compute_outputs
        verify_confined!(target_dir, outputs)

        FileUtils.mkdir_p(target_dir)
        outputs.each do |relative, content|
          destination = File.join(target_dir, relative)
          FileUtils.mkdir_p(File.dirname(destination))
          temp = "#{destination}.tmp.#{Process.pid}"
          begin
            File.binwrite(temp, content)
            File.rename(temp, destination)
          ensure
            FileUtils.rm_f(temp)
          end
        end

        cleanup_stale_files(target_dir, outputs)
        meta_path = @meta_path
        meta_rows = @meta_rows
        Meta.write(meta_path, meta_rows) if meta_path && meta_rows
      end

      private

      # Refuses to build when any output path would escape the output
      # directory. The error is raised before any filesystem write
      # happens.
      #: (String, Hash[String, String]) -> void
      def verify_confined!(target_dir, outputs)
        base = File.expand_path(target_dir)
        outputs.each_key do |key|
          raise Error, 'empty output path in outputs' if key.empty?

          expanded = File.expand_path(key, base)
          next if expanded.start_with?("#{base}#{File::SEPARATOR}")

          raise Error, "unsafe output path #{key.inspect} escapes the output directory"
        end
      end

      # Refuses to build when a page slug or an alias slug names a
      # language this build emits. Originals live at the root and
      # translations under their language code, so such a slug
      # makes the first path segment ambiguous — that page at the
      # root, or that language's home. The build fails instead of
      # routing one of them to the wrong place.
      #: (Hash[String, OriginalPage], Hash[String, MetaRow], Array[String]) -> void
      def verify_no_language_collisions!(originals, meta, languages)
        codes = languages.map(&:downcase)
        originals.each_key do |slug|
          next unless codes.include?(slug.downcase)

          raise Error, "page slug #{slug.inspect} collides with a language code"
        end
        meta.each_value do |row|
          row.aliases.each do |title|
            alias_slug = Slugs.for_title(title)
            next unless codes.include?(alias_slug.downcase)

            raise Error, "alias slug #{alias_slug.inspect} collides with a language code"
          end
        end
      end

      # Refuses to build when a page lacks a version in a declared
      # language. The declared set is a complete matrix: every
      # article — and every special page that exists — exists in
      # every language in it, and an original written outside the
      # set is a row like any other, all its declared versions
      # translations. A missing version is not a gap to route
      # around; the build fails, naming every missing version at
      # once. No set declared, nothing is required.
      #: (page_versions, Array[TranslationRecord]) -> void
      def verify_translation_completeness!(versions, translations)
        return if @supported_languages.empty?

        missing = [] #: Array[String]
        versions.each do |slug, by_language|
          @supported_languages.each do |language|
            missing << "#{slug} (#{language})" unless by_language.key?(language)
          end
        end
        %w[Home _Footer].each do |name|
          next unless @history.tree_entry("#{name}.md")

          present = translations.filter_map { |record| record.language if record.special && record.slug == name }
          site_language = @site_language
          present << site_language if site_language
          @supported_languages.each do |language|
            missing << "#{name} (#{language})" unless present.include?(language)
          end
        end
        return if missing.empty?

        raise Error, "missing translations: #{missing.sort.join(', ')}"
      end

      # Removes stale generated files no longer produced by this build.
      #
      # The output directory is this tool's alone: anything with a
      # generated extension (Markdown or a common image type) that
      # the current build did not produce is removed, at any depth,
      # along with `.tmp.<pid>` files left by a crashed write.
      # Other files (such as site assets shared with the SSG) stay
      # untouched, and directories left empty by a removal are
      # removed as well.
      #: (String, Hash[String, String]) -> void
      def cleanup_stale_files(target_dir, outputs)
        base = File.expand_path(target_dir)
        keep = Set.new(outputs.keys)
        %w[**/*.md **/*.png **/*.jpg **/*.jpeg **/*.gif **/*.webp **/*.svg **/*.tmp.*].each do |pattern|
          Dir.glob(File.join(base, pattern)).each do |path|
            next if keep.include?(path.delete_prefix("#{base}/"))

            FileUtils.rm_f(path)
          end
        end
        Dir.glob(File.join(base, '**', '*'))
           .select { |path| File.directory?(path) }
           .sort
           .reverse
           .each { Dir.rmdir(it) if Dir.empty?(it) }
      end

      # Computes every output the build would produce, returning them as a
      # map of target-relative paths to content. Computing is pure:
      # nothing is written here. The synced META rows are kept for
      # build, which writes META.md back only after every output has
      # been computed and written.
      #: () -> Hash[String, String]
      def compute_outputs
        outputs = {} #: Hash[String, String]

        pages = collect_pages
        meta_path = Pathname(@path.to_s) / 'META.md'
        meta = Meta.sync(self, pages, meta_path, ignore_meta: @ignore_meta, prev_head: @prev_head)
        @meta_path = meta_path
        @meta_rows = meta

        originals = original_records(pages, meta)
        translations = load_translations(originals)
        versions = version_map(originals, translations)
        languages = active_languages(versions, translations)
        verify_no_language_collisions!(originals, meta, languages)
        verify_translation_completeness!(versions, translations)
        routes = routes_by_language(languages, versions, meta)

        originals.each_value do |original|
          page = original.page
          slug = File.basename(page, '.md')
          front_matter = front_matter_with_context(page, meta)
          body = render_page_with_context(page, routes[original.language])
          outputs["#{original.language}/#{slug}.md"] = "#{front_matter}---\n\n#{body}"
        end

        translations.each do |record|
          content = if record.special
                      translated_special_output(record, routes[record.language])
                    else
                      translated_output(record, originals.fetch(record.slug), meta, routes[record.language])
                    end
          outputs["#{record.language}/#{record.slug}.md"] = content
        end

        special_languages = {} #: Hash[String, Set[String]]
        %w[Home _Footer].each do |name|
          file_name = "#{name}.md"
          next unless @history.tree_entry(file_name)

          language = @site_language
          key = language ? "#{language}/#{file_name}" : file_name
          outputs[key] = special_output(name, file_name, language ? routes[language] : nil)
          if language
            (special_languages[name] ||= Set.new) << language
          else
            # Without a site language the special page sits at the root;
            # its slug is still occupied in every language, so no
            # redirect may claim it anywhere.
            languages.each { (special_languages[name] ||= Set.new) << it }
          end
        end
        translations.each do |record|
          next unless record.special

          (special_languages[record.slug] ||= Set.new) << record.language
        end

        redirect_outputs(meta, languages, versions, special_languages).each do |relative, content|
          outputs[relative] = content
        end

        # Image assets are language-neutral, but pages reference them by
        # relative name, so every language directory gets its own copy.
        each_root_entry do |entry|
          path = entry[:name]
          next unless image_asset?(path)

          blob = @repo.lookup(entry[:oid])
          next unless blob.is_a?(Rugged::Blob)

          content = blob.content
          languages.each { outputs["#{it}/#{path}"] = content }
        end

        outputs
      end

      # The original pages of this build, keyed by slug, each with the
      # language the page itself is written in (normalized, so a Chinese
      # page names its script variant).
      #: (Array[String], Hash[String, MetaRow]) -> Hash[String, OriginalPage]
      def original_records(pages, meta)
        records = {} #: Hash[String, OriginalPage]
        pages.each do |page|
          slug = File.basename(page, '.md')
          records[slug] = OriginalPage.new(page:, language: page_language(page, meta))
        end
        records
      end

      # The effective language of an original page: the META row's
      # language when one exists, a detection result otherwise, always
      # normalized (Chinese gains its script variant from the body).
      #: (String, Hash[String, MetaRow]) -> String
      def page_language(page, meta)
        slug = File.basename(page, '.md')
        row = meta[slug]
        raw = row&.language || detect_language(text_for(page))
        normalized = if raw.downcase.start_with?('zh')
                       Language.normalize(raw, text_for(page), supported: @supported_languages)
                     else
                       Language.normalize(raw, supported: @supported_languages)
                     end
        normalized || 'en'
      end

      # Reads the translation files supplied as data under the
      # translations directory: one subdirectory per language, one
      # Markdown file per page, named by the original page's slug;
      # Home and _Footer name the special pages. A file whose
      # language is not supported, whose slug no original page
      # bears, or that restates the original in its own language is
      # refused: dropped silently, it would hole a dataset the site
      # treats as complete.
      #: (Hash[String, OriginalPage]) -> Array[TranslationRecord]
      def load_translations(originals)
        base = @translations_dir
        return [] if base.nil?

        # A translations directory the caller named must exist.
        # Treating a missing directory as "no translations" would
        # build a site that silently lacks every translation.
        raise Error, "translations directory not found: #{base}" unless File.directory?(base)

        records = [] #: Array[TranslationRecord]
        Dir.children(base).sort.each do |entry|
          dir = File.join(base, entry)
          next unless File.directory?(dir)

          language = Language.normalize(entry, supported: @supported_languages)
          next if language.nil?

          unless @supported_languages.empty? || @supported_languages.include?(language)
            raise Error, "translations: #{entry}/ names a language the site does not support"
          end

          Dir.glob(File.join(dir, '*.md')).each do |file|
            records << translation_record(file, language, originals)
          end
        end
        records
      end

      # One translation file as a record, checked against the
      # originals first (load_translations states the rules).
      #: (String, String, Hash[String, OriginalPage]) -> TranslationRecord
      def translation_record(file, language, originals)
        # A file name read from disk may be decomposed (NFD), as
        # macOS stores names, where the wiki's page names are
        # composed (NFC); normalize so the same page is recognized
        # under either form.
        slug = File.basename(file, '.md').unicode_normalize(:nfc)
        raise Error, "translations: #{language}/#{slug}.md is not a safe page name" unless Slugs.safe?(slug)

        special = %w[Home _Footer].include?(slug)
        if special
          if language == @site_language
            raise Error, "translations: #{language}/#{slug}.md restates a special page in its own language"
          end
        elsif !originals.key?(slug)
          raise Error, "translations: #{language}/#{slug}.md has no original page"
        elsif originals.fetch(slug).language == language
          raise Error, "translations: #{language}/#{slug}.md is in the same language as the original page"
        end

        title, body = split_translation_source(File.read(file))
        TranslationRecord.new(slug:, language:, title:, body:, special:)
      end

      # Splits a translation file into its optional front matter title
      # and its body. The front matter is YAML between '---' lines at
      # the very start of the file; +title+ is the only key read.
      #: (String) -> [String?, String]
      def split_translation_source(content)
        content = content.gsub(/\r\n?/, "\n").dup.force_encoding(Encoding::UTF_8)
        content = content.scrub unless content.valid_encoding?
        return [nil, content] unless content.start_with?("---\n")

        lines = content.lines
        closing = lines[1..]&.index("---\n")
        return [nil, content] if closing.nil?

        front_lines = lines[1, closing] || []
        body = (lines[(closing + 2)..] || []).join.sub(/\A\n/, '')
        title_line = front_lines.find { |line| line.start_with?('title:') }
        [title_line ? translation_title(title_line) : nil, body]
      end

      # Reads the value of a front matter 'title:' line, removing one
      # layer of matching quotes when present. Only this one key is
      # read, so the front matter needs no full YAML parse.
      #: (String) -> String?
      def translation_title(line)
        value = line.sub('title:', '').strip
        return nil if value.empty?

        quoted = value.length >= 2 &&
                 ((value.start_with?('"') && value.end_with?('"')) ||
                  (value.start_with?("'") && value.end_with?("'")))
        value = value[1...-1].to_s if quoted
        value.empty? ? nil : value
      end

      # Which languages each page exists in: slug -> language -> true
      # when that version is a translation, false for the original.
      #: (Hash[String, OriginalPage], Array[TranslationRecord]) -> page_versions
      def version_map(originals, translations)
        versions = {} #: Hash[String, Hash[String, bool]]
        originals.each_value do |original|
          slug = File.basename(original.page, '.md')
          (versions[slug] ||= {})[original.language] = false
        end
        translations.each do |record|
          next if record.special

          (versions[record.slug] ||= {})[record.language] = true
        end
        versions
      end

      # Every language this build emits anything in: the originals'
      # languages, the translations' languages, and the site language
      # (the original special pages belong to it).
      #: (page_versions, Array[TranslationRecord]) -> Array[String]
      def active_languages(versions, translations)
        languages = versions.values.flat_map(&:keys) | translations.map(&:language)
        site_language = @site_language
        languages |= [site_language] if site_language
        languages.sort
      end

      # For every emitted language, the routes its pages link with:
      # slug -> the URL prefix a link to that slug must use from a
      # page in this language. Originals live at the root (empty
      # prefix); translations under their language (that prefix).
      # A target with no version in a declared reader's language
      # cannot occur — the completeness check has refused such a
      # build — so reaching it here means the build's own checks
      # disagree, and it fails. In an undeclared language the
      # matrix promises nothing, and the link points at the
      # original at the root instead. Aliases route to their
      # redirect: at the root in the target's original language,
      # under the reader's language elsewhere (see
      # redirect_outputs).
      #: (Array[String], page_versions, Hash[String, MetaRow]) -> Hash[String, link_routes]
      def routes_by_language(languages, versions, meta)
        result = {} #: Hash[String, Hash[String, String]]
        languages.each do |language|
          routes = {} #: Hash[String, String]
          versions.each do |slug, by_language|
            routes[slug] = route_prefix(slug, by_language, language)
          end
          meta.each do |target_slug, row|
            original_language = versions[target_slug]&.key(false)
            prefix = original_language == language ? '' : "/#{language}"
            row.aliases.each { routes[Slugs.for_title(it)] = prefix }
          end
          result[language] = routes
        end
        result
      end

      # The URL prefix of one page as linked from a page in the
      # given language (see routes_by_language for the two cases a
      # missing version can mean).
      #: (String, Hash[String, bool], String) -> String
      def route_prefix(slug, by_language, language)
        unless by_language.key?(language)
          return '' unless @supported_languages.include?(language)

          raise Error, "no #{language} version of page #{slug} to route to"
        end

        by_language[language] ? "/#{language}" : ''
      end

      # Builds one translated article: the original's metadata, the
      # translation's own title when it supplies one, and a body whose
      # wikilinks are resolved for the translation's language.
      #: (TranslationRecord, OriginalPage, Hash[String, MetaRow], Hash[String, String]?) -> String
      def translated_output(record, original, meta, routes)
        slug = record.slug
        with_error_context("could not build translation #{record.language}/#{slug}") do
          row = meta[slug]
          front_matter = {
            'kind' => 'article',
            'title' => record.title || title_for(slug),
            'slug' => slug,
            'author' => row ? row.author : 'unknown',
            'creation_date' => row ? row.creation_date : 'unknown',
            'modified_date' => row ? row.modified_date : 'unknown',
            'language' => record.language,
            'original_language' => original.language,
            'translation' => true
          } #: Hash[String, String | bool]
          front_matter = front_matter.merge('listed' => false) if @unlisted_pages.include?(slug)
          body = Tags.render(record.body, link_index:, routes:)
          "#{front_matter.to_yaml}---\n\n#{body}"
        end
      end

      # Builds one translated special page (Home or _Footer).
      #: (TranslationRecord, Hash[String, String]?) -> String
      def translated_special_output(record, routes)
        front_matter = {
          'kind' => 'special',
          'title' => title_for(record.slug),
          'slug' => record.slug,
          'language' => record.language
        } #: Hash[String, String]
        body = Tags.render(record.body, link_index:, routes:)
        "#{front_matter.to_yaml}---\n\n#{body}"
      end

      # Runs the block, wrapping any failure with a context that
      # identifies the page or file responsible, so a crash
      # mid-build names what it was building.
      #: (String) { () -> String } -> String
      def with_error_context(context)
        yield
      rescue StandardError => e
        raise Error, "#{context}: #{e.class}: #{e.message}"
      end

      # Builds the front matter for one page, wrapping any failure with the
      # page path so a crash mid-build identifies the file responsible.
      #: (String, Hash[String, MetaRow]) -> String
      def front_matter_with_context(page, meta)
        with_error_context("could not build front matter for page #{page}") { article_front_matter(page, meta) }
      end

      # Renders one page, wrapping any failure with the page path so a crash
      # mid-build identifies the file responsible.
      #: (String, ?Hash[String, String]?) -> String
      def render_page_with_context(page, routes = nil)
        with_error_context("could not render page #{page}") { render_page(page, routes) }
      end

      # Special pages are site parts, not articles. The language
      # stamped here is the site language the caller supplied; when
      # none was supplied, the key is omitted rather than invented.
      #: (String, String, ?Hash[String, String]?) -> String
      def special_output(name, file_name, routes = nil)
        front_matter = {
          'kind' => 'special',
          'title' => title_for(name),
          'slug' => name
        } #: Hash[String, String]
        language = @site_language
        front_matter['language'] = language if language
        "#{front_matter.to_yaml}---\n\n#{render_page_with_context(file_name, routes)}"
      end

      # One redirect per alias per emitted language, each in that
      # language's directory. The redirect for a language is skipped
      # when a real page of that language already bears the alias's
      # slug: the existing page always wins over a generated redirect.
      #: (Hash[String, MetaRow], Array[String], page_versions, Hash[String, Set[String]]) -> Hash[String, String]
      def redirect_outputs(meta, languages, versions, special_languages)
        outputs = {} #: Hash[String, String]
        languages.each do |language|
          occupied = occupied_slugs(language, versions, special_languages)
          meta.each do |target_slug, row|
            row.aliases.each do |title|
              alias_slug = Slugs.for_title(title)
              downcased = alias_slug.downcase
              next if occupied.include?(downcased) || downcased == target_slug.downcase

              # A redirect has no body, so it carries no language: language
              # is a property of content, and a stub has none. Consumers
              # that need one resolve it from the target page. The
              # redirect's own language is its directory, nothing more.
              front_matter = {
                'kind' => 'redirect',
                'title' => title,
                'slug' => alias_slug,
                'target_slug' => target_slug
              }.to_yaml
              outputs["#{language}/#{alias_slug}.md"] = "#{front_matter}---\n\n"
            end
          end
        end
        outputs
      end

      # The slugs a redirect must not shadow within one language: the
      # pages that language actually has, its special pages, and the
      # pages the build never generates in any language.
      #: (String, page_versions, Hash[String, Set[String]]) -> Set[String]
      def occupied_slugs(language, versions, special_languages)
        occupied = Set.new(@ungenerated_pages.map(&:downcase))
        versions.each do |slug, by_language|
          occupied << slug.downcase if by_language.key?(language)
        end
        special_languages.each do |name, languages|
          occupied << name.downcase if languages.include?(language)
        end
        occupied
      end

      # Yields each file at the repository root, the only place
      # GitHub Wiki keeps files: subdirectory files are unsupported
      # and ignored, and dotfiles are never wiki pages or assets.
      #: () { (Rugged::tree_entry) -> void } -> void
      def each_root_entry
        @tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          next unless root.empty?

          next if entry[:name].start_with?('.')

          yield entry
        end
      end

      # Whether a root file is an image asset, by its extension.
      #: (String) -> bool
      def image_asset?(name) = IMAGE_EXTENSIONS.include?(File.extname(name).downcase)

      # The pages this build generates, in order: the safe
      # Markdown pages at the repository root that are not
      # ungenerated.
      #: () -> Array[String]
      def collect_pages
        result = [] #: Array[String]
        each_root_entry do |entry|
          path = entry[:name]
          next unless path.end_with?('.md')

          slug = File.basename(path, '.md')
          next unless Slugs.safe?(slug)
          next if @ungenerated_pages.include?(slug)

          result << path
        end
        result.sort!
      end

      #: (String, ?Hash[String, String]?) -> String
      def render_page(name, routes = nil)
        Tags.render(text_for(name), link_index:, routes:)
      end

      # The wiki's link index: every page and image asset at the
      # repository root, for canonicalizing wikilink targets the way
      # GitHub Wiki resolves them (see Tags.build_link_index). All
      # .md files count, generated or not — resolution is about
      # what exists in the wiki, not what this build emits.
      #: () -> link_index
      def link_index
        @link_index ||= begin
          page_slugs = [] #: Array[String]
          asset_names = [] #: Array[String]
          each_root_entry do |entry|
            name = entry[:name]
            page_slugs << File.basename(name, '.md') if name.end_with?('.md')
            asset_names << name if image_asset?(name)
          end
          Tags.build_link_index(page_slugs, asset_names)
        end
      end

      #: (String) -> String
      def detect_language(text) = Language.call(text, supported: @supported_languages)

      # One article's front matter. The values come from the
      # page's META row when it has one, and from git history
      # otherwise.
      #: (String, ?Hash[String, MetaRow]) -> String
      def article_front_matter(page_name, meta = {})
        slug = File.basename(page_name, '.md')
        row = meta[slug]
        # Only inspect git history when the META row does not answer the
        # questions — incremental builds rely on previous rows to skip the
        # history walk entirely.
        bounds = row.nil? ? commit_bounds_for(page_name) : nil
        last = bounds && bounds[:latest]
        first = bounds && bounds[:earliest]
        author = row&.author || (last ? last.author[:name] : 'unknown')
        creation_date = row&.creation_date || (first ? first.time.utc.iso8601 : 'unknown')
        modified_date = row&.modified_date || (last ? last.time.utc.iso8601 : 'unknown')
        language = page_language(page_name, meta)
        front_matter = {
          'kind' => 'article',
          'title' => title_for(slug),
          'slug' => slug,
          'author' => author,
          'creation_date' => creation_date,
          'modified_date' => modified_date,
          'language' => language
        }
        front_matter = front_matter.merge('listed' => false) if @unlisted_pages.include?(slug)
        front_matter.to_yaml
      end

      #: (String) -> String
      def title_for(slug) = Slugs.title_for(slug)
    end
  end
end
