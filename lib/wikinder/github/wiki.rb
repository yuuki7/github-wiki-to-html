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
require_relative 'wiki/meta'

module Wikinder
  module GitHub
    # Represents a GitHub Wiki repository as a coherent set of Markdown pages.
    #
    # The wiki repository contains .md files; this class enumerates them,
    # rewrites wiki-specific syntax, and produces YAML front matter
    # with metadata for downstream consumers.
    #
    # GitHub Wiki is flat: it has no notion of nested page directories, and
    # pages are addressed by name only. Subdirectory blobs are therefore
    # silently unsupported — they are ignored entirely.
    class Wiki
      # @rbs @path: Pathname
      # @rbs @repo: Rugged::Repository
      # @rbs @commit_bounds: Hash[String, Hash[Symbol, Rugged::Commit?]]
      # @rbs @rename_deltas: Hash[String, String]
      # @rbs @diffs: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]
      # @rbs @link_index: Hash[Symbol, Hash[String, String]]?
      # @rbs @tree: Rugged::Tree
      # @rbs @ignore_meta: bool
      # @rbs @prev_head: String?
      # @rbs @site_language: String?
      # @rbs @supported_languages: Array[String]
      # @rbs @translations_dir: String?

      attr_reader :head #: String
      attr_reader :ungenerated_pages #: Set[String]
      attr_reader :unlisted_pages #: Set[String]

      # Creates a new wiki instance.
      #
      # @param path [String | Pathname] path to the wiki repository.
      # @param options [Hash] unlisted_pages/ungenerated_pages Sets.
      #   ungenerated_pages defaults to Set['Home', 'README', 'LICENSE',
      #   'META', '_Footer'] — the same set the conversion CLI passes —
      #   so Home/_Footer are not emitted as ordinary articles by default.
      #   Pass Set['META'] (or any subset) explicitly to opt out of each.
      # @param options[:ignore_meta] Ignore committed META.md and derive
      #   authorship metadata from git history instead. Used for testing.
      # @param options[:prev_head] SHA of the commit this repo was last read
      #   at. Used for incremental META.md sync.
      # @param options[:site_language] The site's language, stamped onto
      #   special pages. Site metadata is the caller's business (the
      #   conversion CLI maintains it); the module never reads a site
      #   file itself and never detects a language for site parts.
      #   It is also the language the original special pages belong to:
      #   every output is written under a language directory named by
      #   the page's own language.
      # @param options[:supported_languages] The languages the site
      #   offers translations in. Translation directories naming any
      #   other language are ignored. When empty, every language found
      #   under the translations directory is accepted.
      # @param options[:translations_dir] Directory holding translated
      #   pages as data, one subdirectory per language
      #   (translations/<language>/<Slug>.md). Translation itself is
      #   not this module's business; the files are inputs, produced
      #   elsewhere, and may carry a YAML front matter whose only key
      #   the converter reads is +title+ (the translated title).
      #: (String | Pathname, ?wiki_options) -> void
      def initialize(path, options = {})
        @path = Pathname(path.to_s).expand_path
        @repo = Rugged::Repository.new(@path.to_s)
        @head = @repo.head.target_id
        # Capture the tree once so walking / lookup during build does not
        # change mid-build (the wiki could otherwise move under a build).
        @tree = (@repo.rev_parse(@head) || @repo.head.target).tree
        @ungenerated_pages = Array(
          options.fetch(:ungenerated_pages) { Set['Home', 'README', 'LICENSE', 'META', '_Footer'] }
        ).to_set.freeze
        @unlisted_pages = Array(options[:unlisted_pages] || []).to_set.freeze
        @ignore_meta = options[:ignore_meta] == true
        prev_head = options[:prev_head]
        @prev_head = prev_head.is_a?(String) ? prev_head : nil
        site_language = options[:site_language]
        @site_language = site_language.is_a?(String) ? Language.normalize(site_language) : nil
        supported = options[:supported_languages]
        supported_list = [] #: Array[String]
        supported_list = supported.filter_map { |code| Language.normalize(code.to_s) } if supported.is_a?(Array)
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
      end

      private

      # Refuses to build when any output path would escape the output
      # directory — callers get a loud error before any filesystem write
      # happens.
      #: (String, Hash[String, String]) -> void
      def verify_confined!(target_dir, outputs)
        base = File.expand_path(target_dir)
        outputs.each_key do |key|
          raise 'error: empty output path in outputs' if key.empty?

          expanded = File.expand_path(key, base)
          next if expanded.start_with?("#{base}#{File::SEPARATOR}")

          raise "error: unsafe output path #{key.inspect} escapes the output directory"
        end
      end

      # Removes stale generated files no longer produced by this build.
      #
      # The output directory is assumed to be exclusively this tool's
      # destination — anything matching the generated extensions (Markdown
      # or common image types) that the current build did not produce is
      # removed, at any depth (outputs live in per-language directories),
      # along with `.tmp.<pid>` stragglers from a crash-during-write.
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
      # map of target-relative paths to content. Meta.sync! still mutates
      # META.md in the source tree (that is its job); everything else happens
      # purely in memory.
      #: () -> Hash[String, String]
      def compute_outputs
        outputs = {} #: Hash[String, String]

        pages = collect_pages
        meta_path = Pathname(@path.to_s) / 'META.md'
        meta = Meta.sync!(self, pages, meta_path, ignore_meta: @ignore_meta, prev_head: @prev_head)

        originals = original_records(pages, meta)
        translations = load_translations(originals)
        versions = version_map(originals, translations)
        languages = active_languages(versions, translations)
        routes = routes_by_language(languages, versions, meta)

        originals.each_value do |original|
          page = original[:page]
          slug = File.basename(page, '.md')
          front_matter = front_matter_with_context(page, meta)
          body = render_page_with_context(page, routes[original[:language]])
          outputs["#{original[:language]}/#{slug}.md"] = "#{front_matter}---\n\n#{body}"
        end

        translations.each do |record|
          content = if record[:special]
                      translated_special_output(record, routes[record[:language]])
                    else
                      translated_output(record, originals.fetch(record[:slug]), meta, routes[record[:language]])
                    end
          outputs["#{record[:language]}/#{record[:slug]}.md"] = content
        end

        special_languages = {} #: Hash[String, Set[String]]
        %w[Home _Footer].each do |name|
          file_name = "#{name}.md"
          next unless tree_entry(file_name)

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
          next unless record[:special]

          (special_languages[record[:slug]] ||= Set.new) << record[:language]
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

          content = @repo.lookup(entry[:oid]).content
          languages.each { |language| outputs["#{language}/#{path}"] = content }
        end

        outputs
      end

      # The original pages of this build, keyed by slug, each with the
      # language the page itself is written in (normalized, so a Chinese
      # page names its script variant).
      #: (Array[String], Hash[String, meta_row]) -> Hash[String, original_page]
      def original_records(pages, meta)
        records = {} #: Hash[String, original_page]
        pages.each do |page|
          slug = File.basename(page, '.md')
          records[slug] = { page: page, language: page_language(page, meta) }
        end
        records
      end

      # The effective language of an original page: the META row's
      # language when one exists, a detection result otherwise, always
      # normalized (Chinese gains its script variant from the body).
      #: (String, Hash[String, meta_row]) -> String
      def page_language(page, meta)
        slug = File.basename(page, '.md')
        row = meta[slug]
        raw = row ? row[:language] : detect_language(text_for(page))
        normalized = if raw&.downcase&.start_with?('zh')
                       Language.normalize(raw, text_for(page))
                     else
                       Language.normalize(raw)
                     end
        normalized || 'en'
      end

      # Reads the translation files supplied as data under the
      # translations directory: one subdirectory per language, one
      # Markdown file per page, named by the original page's slug.
      # Home and _Footer name the special pages. A file is skipped,
      # with a warning, when its language is not supported, when no
      # original page bears its slug, or when it merely restates the
      # original in the original's own language.
      #: (Hash[String, original_page]) -> Array[translation_record]
      def load_translations(originals)
        base = @translations_dir
        return [] if base.nil?
        return [] unless File.directory?(base)

        records = [] #: Array[translation_record]
        Dir.children(base).sort.each do |entry|
          dir = File.join(base, entry)
          next unless File.directory?(dir)

          language = Language.normalize(entry)
          next if language.nil?

          unless @supported_languages.empty? || @supported_languages.include?(language)
            warn "translations: ignoring #{entry}/ (language is not in the site's supported languages)"
            next
          end

          Dir.glob(File.join(dir, '*.md')).each do |file|
            record = translation_record(file, language, originals)
            records << record if record
          end
        end
        records
      end

      #: (String, String, Hash[String, original_page]) -> translation_record?
      def translation_record(file, language, originals)
        slug = File.basename(file, '.md')
        return nil unless Slugs.safe?(slug)

        special = %w[Home _Footer].include?(slug)
        if special
          if language == @site_language
            warn "translations: ignoring #{language}/#{slug}.md (the original special page is used for this language)"
            return nil
          end
        elsif !originals.key?(slug)
          warn "translations: ignoring #{language}/#{slug}.md (no original page has this slug)"
          return nil
        elsif originals.fetch(slug)[:language] == language
          warn "translations: ignoring #{language}/#{slug}.md (same language as the original page)"
          return nil
        end

        title, body = split_translation_source(File.read(file))
        { slug: slug, language: language, title: title, body: body, special: special }
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
      #: (Hash[String, original_page], Array[translation_record]) -> page_versions
      def version_map(originals, translations)
        versions = {} #: Hash[String, Hash[String, bool]]
        originals.each_value do |original|
          slug = File.basename(original[:page], '.md')
          (versions[slug] ||= {})[original[:language]] = false
        end
        translations.each do |record|
          next if record[:special]

          (versions[record[:slug]] ||= {})[record[:language]] = true
        end
        versions
      end

      # Every language this build emits anything in: the originals'
      # languages, the translations' languages, and the site language
      # (home of the original special pages).
      #: (page_versions, Array[translation_record]) -> Array[String]
      def active_languages(versions, translations)
        languages = Set.new
        versions.each_value { |by_language| by_language.each_key { |language| languages << language } }
        translations.each { |record| languages << record[:language] }
        languages << @site_language if @site_language
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
      #: (Array[String], page_versions, Hash[String, meta_row]) -> Hash[String, Hash[String, String]]
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
            row[:aliases].each { |title| routes[Slugs.for_title(title)] = prefix }
          end
          result[language] = routes
        end
        result
      end

      # Builds one translated article: the original's metadata, the
      # translation's own title when it supplies one, and a body whose
      # wikilinks are resolved for the translation's language.
      #: (translation_record, original_page, Hash[String, meta_row], Hash[String, String]?) -> String
      def translated_output(record, original, meta, routes)
        slug = record[:slug]
        row = meta[slug]
        front_matter = {
          'kind' => 'article',
          'title' => record[:title] || title_for(slug),
          'slug' => slug,
          'author' => row ? row[:author] : 'unknown',
          'creation_date' => row ? row[:creation_date] : 'unknown',
          'modified_date' => row ? row[:modified_date] : 'unknown',
          'language' => record[:language],
          'original_language' => original[:language],
          'translation' => true
        } #: Hash[String, String | bool]
        front_matter = front_matter.merge('listed' => false) if @unlisted_pages.include?(slug)
        body = Tags.render(record[:body], link_index: link_index, routes: routes)
        "#{front_matter.to_yaml}---\n\n#{body}"
      rescue StandardError => e
        raise "could not build translation #{record[:language]}/#{slug}: #{e.class}: #{e.message}"
      end

      # Builds one translated special page (Home or _Footer).
      #: (translation_record, Hash[String, String]?) -> String
      def translated_special_output(record, routes)
        front_matter = {
          'kind' => 'special',
          'title' => title_for(record[:slug]),
          'slug' => record[:slug],
          'language' => record[:language]
        } #: Hash[String, String]
        body = Tags.render(record[:body], link_index: link_index, routes: routes)
        "#{front_matter.to_yaml}---\n\n#{body}"
      end

      # Builds the front matter for one page, wrapping any failure with the
      # page path so a crash mid-build identifies the file responsible.
      #: (String, Hash[String, meta_row]) -> String
      def front_matter_with_context(page, meta)
        article_front_matter(page, meta)
      rescue StandardError => e
        raise "could not build front matter for page #{page}: #{e.class}: #{e.message}"
      end

      # Renders one page, wrapping any failure with the page path so a crash
      # mid-build identifies the file responsible.
      #: (String, ?Hash[String, String]?) -> String
      def render_page_with_context(page, routes = nil)
        render_page(page, routes)
      rescue StandardError => e
        raise "could not render page #{page}: #{e.class}: #{e.message}"
      end

      # Special pages are site parts, not articles: their language is
      # the site's language as supplied by the caller, never a language
      # detected from the body. When the caller supplies none, the key
      # is omitted rather than invented.
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
      #: (Hash[String, meta_row], Array[String], page_versions, Hash[String, Set[String]]) -> Hash[String, String]
      def redirect_outputs(meta, languages, versions, special_languages)
        outputs = {} #: Hash[String, String]
        languages.each do |language|
          occupied = occupied_slugs(language, versions, special_languages)
          meta.each do |target_slug, row|
            row[:aliases].each do |title|
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

      public

      # Looks up a path in the HEAD tree. GitHub Wiki is flat, so a plain
      # tree lookup always suffices.
      #: (String, ?tree: Rugged::Tree?) -> Rugged::tree_entry?
      def tree_entry(path, tree: nil)
        (tree || @tree)[path]
      end

      #: (String) -> String
      def text_for(name)
        entry = tree_entry(name)
        return '' unless entry

        content = @repo.lookup(entry[:oid]).content
        # Normalise CR and CRLF line endings; the Commonmarker parser walks
        # \r\n and bare \r as distinct line separators, so CR-only files
        # would otherwise crash range_for with offsets past the end of
        # line_offsets. This mirrors Gollum's Wiki#normalize.
        content = content.gsub(/\r\n?/, "\n")
        content = content.force_encoding(Encoding::UTF_8)
        return content if content.valid_encoding?

        warn "text_for: #{name} contains invalid UTF-8; invalid bytes were replaced with U+FFFD"
        content.scrub
      end

      #: (String) -> Hash[Symbol, Rugged::Commit?]
      def commit_bounds_for(path)
        @commit_bounds ||= {} #: Hash[String, Hash[Symbol, Rugged::Commit?]]
        return @commit_bounds[path] if @commit_bounds.key?(path)

        earliest = nil #: Rugged::Commit?
        latest = nil #: Rugged::Commit?
        # Include commits that touched any of the paths this page was
        # renamed from, so tree/time bounds reflect the history of the
        # logical page across renames.
        paths = [path] + rename_history_for(path)
        @repo.walk('HEAD').each do |commit|
          next unless paths.any? { |candidate| touched?(commit, candidate) }

          time = commit.time
          earliest = commit if earliest.nil? || time < earliest.time
          latest = commit if latest.nil? || time > latest.time
        end
        @commit_bounds[path] = { earliest: earliest, latest: latest }
      end

      # Returns the file paths changed between two refs. A full rebuild
      # returns nil (meaning "everything changed") so the sync treats every
      # page as changed and rewrites every row.
      #: (String?) -> Array[String]?
      def diff_paths(from_ref)
        return nil if from_ref.nil?
        return [] if from_ref == @head

        prev_commit = rev_parse(from_ref)
        return nil unless prev_commit

        head_commit = @repo.rev_parse(@head)
        return nil unless head_commit

        prev_commit.diff(head_commit)
                   .deltas
                   .flat_map { |delta| [delta.old_file[:path], delta.new_file[:path]] }
                   .uniq
      end

      #: (String) -> Rugged::Commit?
      def rev_parse(from_ref)
        @repo.rev_parse(from_ref)
      rescue Rugged::Error
        nil
      end

      #: (Rugged::Commit, Rugged::Commit) -> Rugged::Diff
      def cached_diff(commit, parent)
        @diffs ||= {} #: Hash[[Rugged::Commit, Rugged::Commit], Rugged::Diff]
        @diffs[[commit, parent]] ||= commit.diff(parent)
      end

      # Returns the file paths this page was renamed from, most recent first,
      # based on git rename detection across history.
      #: (String) -> Array[String]
      def rename_history_for(path)
        renames = rename_deltas #: Hash[String, String]
        result = [] #: Array[String]
        current = path #: String
        visited = [current] #: Array[String]
        until (predecessor = renames[current]).nil?
          break if visited.include?(predecessor) # guard against rename cycles

          result << predecessor
          current = predecessor
          visited << current
        end
        result
      end

      # Builds a map of rename deltas across the full history: every file path
      # that was ever renamed maps to its predecessor path.
      # Additionally, surface a warning when a single commit deletes one
      # .md file and adds another .md file with no detectable rename —
      # that is the most likely shape of a rename+rewrite that git cannot
      # link statistically. The wiki schema can only pick one answer when
      # similarity is low, so the author should curate the alias by hand.
      #
      # One diff is computed per (commit, parent) pair and shared with
      # touched? through cached_diff. The plain delta list is snapshotted
      # before find_similar! runs, because similarity detection consumes
      # exactly the added/deleted pairs warn_unlinked_rename looks for.
      #: () -> Hash[String, String]
      def rename_deltas
        @rename_deltas ||= begin
          map = {} #: Hash[String, String]
          @repo.walk('HEAD').each do |commit|
            commit.parents.each do |parent|
              diff = cached_diff(commit, parent)
              plain = plain_delta_paths(diff)
              diff.find_similar!(renames: true)
              marked_renames = Set.new
              diff.deltas.each do |delta|
                next unless delta.status == :renamed

                # Rugged's +commit.diff(parent)+ reports the commit side as
                # old_file and the parent side as new_file (chronologically
                # reversed). The rename map therefore reads "current name ->
                # name it was renamed from". First seen wins; walked from
                # HEAD so the most recent rename is recorded first.
                #
                # The paths are normalised to valid UTF-8 here so all
                # downstream consumers (slug/alias handling, front-matter
                # YAML) can treat them as plain Strings without ever having
                # to worry about ASCII-8BIT.
                newer = delta.old_file[:path].dup.force_encoding(Encoding::UTF_8)
                older = delta.new_file[:path].dup.force_encoding(Encoding::UTF_8)
                map[newer] ||= older
                marked_renames.add(newer)
                marked_renames.add(older)
              end
              warn_unlinked_rename(plain, marked_renames)
            end
          end
          map
        end
      end

      # Snapshots a diff's [status, path] pairs before rename detection
      # rewrites them. Paths are normalised to UTF-8 like the rename
      # map's, so they can be compared against it directly.
      #: (Rugged::Diff) -> Array[[Symbol, String]]
      def plain_delta_paths(diff)
        diff.deltas.map do |delta|
          [delta.status, delta.old_file[:path].to_s.dup.force_encoding(Encoding::UTF_8)]
        end
      end

      # Emits a one-line warning when the commit deletes an .md file and adds
      # another .md file, and the git rename detector found no link between
      # them. This is the usual telltale shape of "rename and fully rewrite".
      # Has no effect on the returned rows; only diagnostics.
      #
      # +plain+ is the pre-similarity snapshot of the reversed diff
      # (commit side as old), so a forward deletion appears as :added
      # and a forward addition as :deleted.
      #: (Array[[Symbol, String]], Set[String]) -> void
      def warn_unlinked_rename(plain, marked_renames)
        deleted_md = [] #: Array[String]
        added_md = [] #: Array[String]
        plain.each do |status, path|
          next unless md?(path)

          deleted_md << path if status == :added
          added_md << path if status == :deleted
        end

        unmatched_deleted = deleted_md - marked_renames.to_a
        unmatched_added = added_md - marked_renames.to_a
        return if unmatched_deleted.empty? || unmatched_added.empty?

        deleted_list = unmatched_deleted.uniq.join(', ')
        added_list = unmatched_added.uniq.join(', ')
        warn 'git could not link this rename: ' \
             "#{added_list} seems to succeed #{deleted_list} after a heavy rewrite; " \
             'alias must be set in META.md manually'
      end

      #: (String) -> bool
      def md?(path)
        path.end_with?('.md')
      end

      private

      #: (String, ?Hash[String, String]?) -> String
      def render_page(name, routes = nil)
        Tags.render(text_for(name), link_index: link_index, routes: routes)
      end

      # The wiki's link index: every page and image asset at the
      # repository root, for canonicalizing wikilink targets the way
      # GitHub Wiki resolves them (see Tags.build_link_index). Pages are
      # all .md files here, generated or not — resolution is about what
      # exists in the wiki, not about what this build emits.
      #: () -> Hash[Symbol, Hash[String, String]]
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
      def detect_language(text) = Language.call(text)

      #: (Rugged::Commit, String) -> bool
      def touched?(commit, path)
        parents = commit.parents
        return !tree_entry(path, tree: commit.tree).nil? if parents.empty?

        path_b = path.b
        parents.any? do |parent|
          cached_diff(commit, parent).deltas.any? do |delta|
            delta.new_file[:path].b == path_b || delta.old_file[:path].b == path_b
          end
        end
      end

      # The wiki repository is flat: all pages live at the repository root,
      # so a single tree lookup resolves the path.

      #: (String, ?Hash[String, meta_row]) -> String
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
                   row[:author]
                 elsif last
                   last.author[:name] || 'unknown'
                 else
                   'unknown'
                 end
        creation_date = if row
                          row[:creation_date]
                        elsif first
                          first.time.utc.iso8601
                        else
                          'unknown'
                        end
        modified_date = if row
                          row[:modified_date]
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
