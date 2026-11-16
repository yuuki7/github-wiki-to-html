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
    # The wiki repository contains .md files; this class enumerates them,
    # rewrites wiki-specific syntax, and produces YAML front matter
    # with metadata for downstream consumers.
    #
    # GitHub Wiki is flat: it has no notion of nested page directories, and
    # pages are addressed by name only. Subdirectory blobs are therefore
    # silently unsupported — they are ignored entirely.
    class Wiki
      # The error a build fails with on purpose: bad input, an
      # unsupported translation, an unsafe output path. Callers can
      # rescue this class to tell such failures apart from bugs and
      # library errors.
      class Error < StandardError; end

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
      #   build never generates as articles. The default is the
      #   same set the conversion CLI passes — the site parts and
      #   repository files that are not articles — so Home and
      #   _Footer are not emitted as ordinary articles by default.
      #   Pass Set['META'] (or any subset) explicitly to opt out of
      #   each.
      # @option options [Set[String]] :unlisted_pages Pages kept out
      #   of the home page's list of articles.
      # @option options [Boolean] :ignore_meta Ignore committed
      #   META.md and derive authorship metadata from git history
      #   instead. Used for testing.
      # @option options [String, nil] :prev_head SHA of the commit
      #   this repo was last read at. Used for incremental META.md
      #   sync.
      # @option options [String, nil] :site_language The site's
      #   language, stamped onto special pages. Site metadata belongs
      #   to the caller (the conversion CLI maintains it); the
      #   module never reads a site file itself and never detects a
      #   language for site parts. It is also the language the
      #   original special pages belong to: every output is written
      #   under a language directory named by the page's own
      #   language.
      # @option options [Array[String]] :supported_languages The
      #   languages the site offers translations in. A translation
      #   directory naming any other language fails the build. When
      #   empty, every language found under the translations
      #   directory is accepted.
      # @option options [String, Pathname, nil] :translations_dir
      #   Directory holding translated pages as data, one
      #   subdirectory per language
      #   (translations/<language>/<Slug>.md). Translation itself is
      #   not this module's business; the files are inputs, produced
      #   elsewhere, and may carry a YAML front matter whose only key
      #   the converter reads is +title+ (the translated title).
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
        @site_language = site_language.is_a?(String) ? Language.normalize(site_language, supported: supported) : nil
        supported_list = supported.filter_map { |code| Language.normalize(code, supported: supported) }
        @supported_languages = supported_list.uniq.freeze
        translations_dir = options[:translations_dir]
        @translations_dir = translations_dir ? Pathname(translations_dir.to_s).expand_path.to_s : nil
      end

      # Builds the entire output tree, writing Markdown files with YAML front matter.
      #
      # All outputs are computed in memory first; only when computation of
      # every page (or asset) succeeded are files written, each via a
      # same-directory temporary file atomically renamed into place. A crash
      # can therefore leave previous-generation and new files mixed, but
      # never a torn individual file. After the write, files the new build
      # no longer produces are removed (keeping anything unrelated to the
      # build untouched).
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

      # Removes stale generated files no longer produced by this build.
      #
      # The output directory is assumed to be exclusively this tool's
      # destination — anything matching the generated extensions (Markdown
      # or common image types) that the current build did not produce is
      # removed, at any depth (outputs live in per-language directories),
      # along with `.tmp.<pid>` files left by a crash during a write.
      # Files with other extensions (e.g. site assets shared with the SSG)
      # are left untouched. Directories left empty by a removal (a
      # language with no pages left) are removed as well.
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
           .each { |dir| Dir.rmdir(dir) if Dir.empty?(dir) }
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
            languages.each { |any| (special_languages[name] ||= Set.new) << any }
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
        image_extensions = %w[.png .jpg .jpeg .gif .webp .svg]
        @tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          next unless root.empty? # subdirectory assets are unsupported and ignored

          path = entry[:name]
          next unless image_extensions.include?(File.extname(path).downcase)
          next if path.start_with?('.') # dotfiles are never wiki assets

          blob = @repo.lookup(entry[:oid])
          next unless blob.is_a?(Rugged::Blob)

          content = blob.content
          languages.each { |language| outputs["#{language}/#{path}"] = content }
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
          records[slug] = OriginalPage.new(page: page, language: page_language(page, meta))
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
        raw = row ? row.language : detect_language(text_for(page))
        normalized = if raw&.downcase&.start_with?('zh')
                       Language.normalize(raw, text_for(page), supported: @supported_languages)
                     else
                       Language.normalize(raw, supported: @supported_languages)
                     end
        normalized || 'en'
      end

      # Reads the translation files supplied as data under the
      # translations directory: one subdirectory per language, one
      # Markdown file per page, named by the original page's slug.
      # Home and _Footer name the special pages. The build refuses
      # a file whose language is not supported, whose slug no
      # original page bears, or that restates the original in the
      # original's own language: dropped silently, it would leave a
      # hole in a dataset the site treats as complete.
      #: (Hash[String, OriginalPage]) -> Array[TranslationRecord]
      def load_translations(originals)
        base = @translations_dir
        return [] if base.nil?
        return [] unless File.directory?(base)

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
        TranslationRecord.new(slug: slug, language: language, title: title, body: body, special: special)
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
        languages = Set.new #: Set[String]
        versions.each_value { |by_language| by_language.each_key { |language| languages << language } }
        translations.each { |record| languages << record.language }
        site_language = @site_language
        languages << site_language if site_language
        languages.to_a.sort
      end

      # For every emitted language, the routes its pages link with:
      # slug -> the URL prefix a link to that slug must use from a
      # page in this language. An original page lives at the site
      # root, so its prefix is empty; a translation lives under its
      # language, so its prefix is that language. A target that
      # exists as a translation in the reader's language wins;
      # anything else falls back to the original at the root.
      # Aliases route to the redirect generated for them, which is
      # served at the root in the target's original language and
      # under the reader's language elsewhere (see redirect_outputs).
      #: (Array[String], page_versions, Hash[String, MetaRow]) -> Hash[String, link_routes]
      def routes_by_language(languages, versions, meta)
        result = {} #: Hash[String, Hash[String, String]]
        languages.each do |language|
          routes = {} #: Hash[String, String]
          versions.each do |slug, by_language|
            routes[slug] = by_language[language] ? "/#{language}" : ''
          end
          meta.each do |target_slug, row|
            original_language = versions[target_slug]&.key(false)
            prefix = original_language == language ? '' : "/#{language}"
            row.aliases.each { |title| routes[Slugs.for_title(title)] = prefix }
          end
          result[language] = routes
        end
        result
      end

      # Builds one translated article: the original's metadata, the
      # translation's own title when it supplies one, and a body whose
      # wikilinks are resolved for the translation's language.
      #: (TranslationRecord, OriginalPage, Hash[String, MetaRow], Hash[String, String]?) -> String
      def translated_output(record, original, meta, routes)
        slug = record.slug
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
        body = Tags.render(record.body, link_index: link_index, routes: routes)
        "#{front_matter.to_yaml}---\n\n#{body}"
      rescue StandardError => e
        raise Error, "could not build translation #{record.language}/#{slug}: #{e.class}: #{e.message}"
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
        body = Tags.render(record.body, link_index: link_index, routes: routes)
        "#{front_matter.to_yaml}---\n\n#{body}"
      end

      # Builds the front matter for one page, wrapping any failure with the
      # page path so a crash mid-build identifies the file responsible.
      #: (String, Hash[String, MetaRow]) -> String
      def front_matter_with_context(page, meta)
        article_front_matter(page, meta)
      rescue StandardError => e
        raise Error, "could not build front matter for page #{page}: #{e.class}: #{e.message}"
      end

      # Renders one page, wrapping any failure with the page path so a crash
      # mid-build identifies the file responsible.
      #: (String, ?Hash[String, String]?) -> String
      def render_page_with_context(page, routes = nil)
        render_page(page, routes)
      rescue StandardError => e
        raise Error, "could not render page #{page}: #{e.class}: #{e.message}"
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

      # The pages this build generates, in order: the safe
      # Markdown pages at the repository root that are not
      # ungenerated.
      #: () -> Array[String]
      def collect_pages
        result = [] #: Array[String]
        @tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          next unless root.empty? # subdirectory files are unsupported and ignored

          path = entry[:name]
          next unless path.end_with?('.md')
          next if path.start_with?('.') # dotfiles are never wiki pages

          slug = File.basename(path, '.md')
          next unless Slugs.safe?(slug)
          next if @ungenerated_pages.include?(slug)

          result << path
        end
        result.sort!
      end

      #: (String, ?Hash[String, String]?) -> String
      def render_page(name, routes = nil)
        Tags.render(text_for(name), link_index: link_index, routes: routes)
      end

      # The wiki's link index: every page and image asset at the
      # repository root, for canonicalizing wikilink targets the way
      # GitHub Wiki resolves them (see Tags.build_link_index). Pages are
      # all .md files here, generated or not — resolution is about what
      # exists in the wiki, not about what this build emits.
      #: () -> link_index
      def link_index
        @link_index ||= begin
          page_slugs = [] #: Array[String]
          asset_names = [] #: Array[String]
          image_extensions = %w[.png .jpg .jpeg .gif .webp .svg]
          @tree.walk(:preorder) do |root, entry|
            next unless entry[:type] == :blob
            next unless root.empty? # subdirectory files are unsupported and ignored

            name = entry[:name]
            next if name.start_with?('.') # dotfiles are never wiki pages or assets

            page_slugs << File.basename(name, '.md') if name.end_with?('.md')
            asset_names << name if image_extensions.include?(File.extname(name).downcase)
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
        author = if row
                   row.author
                 elsif last
                   last.author[:name]
                 else
                   'unknown'
                 end
        creation_date = if row
                          row.creation_date
                        elsif first
                          first.time.utc.iso8601
                        else
                          'unknown'
                        end
        modified_date = if row
                          row.modified_date
                        elsif last
                          last.time.utc.iso8601
                        else
                          'unknown'
                        end
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
