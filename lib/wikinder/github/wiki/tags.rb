# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'nokogiri'
require 'nokogiri/html5'

module Wikinder
  module GitHub
    class Wiki
      # Converts the GitHub Wiki Markdown dialect to standard GFM Markdown.
      #
      # Wikilinks use the double-bracket syntax: [[Page]], [[Page|Display]],
      # images either use ![[image.png]] or reference a file by its image
      # extension: [[image.png]] is taken to be an image.
      #
      # Wiki links become standard Markdown links, except when they appear
      # in raw HTML blocks, where the Markdown pipeline would not process
      # them. Raw HTML blocks are handed to Nokogiri (HTML5 parser) so text
      # between tags can be rewritten with raw HTML anchors and verbatim
      # parts — tags, attributes, scripts, styles, comments — pass through
      # untouched.
      module Tags
        # Elements treated as raw text by HTML5 — their contents are not
        # recursively parsed, so wikilinks there must not be rewritten.
        RAW_TEXT_ELEMENTS = %w[script style textarea title].freeze #: Array[String]
        WIKILINK_PATTERN = /!?\[\[([^\[\]\n]{1,400})\]\]/
        IMAGE_EXTENSIONS = /\.(png|jpe?g|gif|webp|svg)([?#].*)?\z/i

        #: (String) -> String
        def self.render(source)
          offsets = line_offsets(source)
          segments = typed_ranges(source, offsets)
          rewrite(source, segments)
        end

        #: (String) -> Array[Integer]
        def self.line_offsets(source)
          offsets = [] #: Array[Integer]
          pos = 0
          source.each_line do |line|
            offsets << pos
            pos += line.bytesize
          end
          offsets
        end

        # The segments are [[range, replacement_string]]. The replacement is
        # either the verbatim source bytes (for tags/code/inline HTML that
        # stay as written) or a rewritten fragment — Nokogiri output for
        # raw HTML blocks.
        #: (String, Array[Integer]) -> Array[[Range[Integer], String]]
        def self.typed_ranges(source, offsets)
          ranges = [] #: Array[[Range[Integer], String]]
          Commonmarker.parse(source, options: { extension: { math_dollars: true, math_code: true } }).walk do |node|
            type = node.type.to_s
            sp = node.source_position
            case type
            when 'code', 'code_block', 'math', 'html_inline'
              # Inline HTML tag — verbatim (attrs stay exactly as written).
              sp_range = range_for(offsets, sp)
              ranges << [sp_range, source.byteslice(sp_range).to_s]
            when 'html_block'
              sp_range = range_for(offsets, sp)
              ranges << [sp_range, rewrite_html_block(source.byteslice(sp_range).to_s)]
            end
          end
          ranges.sort_by! { |range, _replacement| range.begin }
          ranges
        end

        # Rewrites wikilinks in an HTML block: parses with Nokogiri and
        # splits each text node at wikilinks, producing anchor/image elements.
        # Raw-text element contents (script, style, textarea, title) are
        # left verbatim, as are attribute values.
        #: (String) -> String
        def self.rewrite_html_block(fragment_text)
          raw = fragment_text.dup.force_encoding(Encoding::UTF_8)
          fragment = Nokogiri::HTML5.fragment(raw)
          fragment.traverse do |node|
            next unless node.text?
            next if inside_raw_text?(node)

            split_and_replace_wikilinks(node)
          end
          fragment.to_html
        end

        #: (Nokogiri::XML::Node) -> bool
        def self.inside_raw_text?(node)
          node.ancestors.any? { |ancestor| RAW_TEXT_ELEMENTS.include?(ancestor.name.downcase) }
        end

        #: (Nokogiri::XML::Node) -> void
        def self.split_and_replace_wikilinks(node)
          text = node.content
          return unless text.include?('[[')

          document = node.document
          nodes = [] #: Array[Nokogiri::XML::Node]
          rest = text.dup
          while (match = rest.match(WIKILINK_PATTERN))
            pre = rest[0...match.begin(0)]
            nodes << Nokogiri::XML::Text.new(pre, document) if pre.is_a?(String) && !pre.empty?

            nodes << build_element(document, match)
            rest = rest[match.end(0)..]
          end
          nodes << Nokogiri::XML::Text.new(rest, document) if rest.is_a?(String) && !rest.empty?
          return if nodes.empty?

          node.replace(Nokogiri::XML::NodeSet.new(document, nodes))
        end

        #: (Nokogiri::XML::Document, MatchData) -> Nokogiri::XML::Node
        def self.build_element(document, match)
          inner = match[1].to_s.strip
          if match[0].to_s.start_with?('!') || image_target?(inner)
            build_image(document, inner)
          else
            build_anchor(document, inner)
          end
        end

        #: (Nokogiri::XML::Document, String) -> Nokogiri::XML::Node
        def self.build_anchor(document, inner)
          href, label = split_ref(inner)
          element = document.create_element('a')
          element['href'] = href
          element.content = label
          element
        end

        #: (Nokogiri::XML::Document, String) -> Nokogiri::XML::Node
        def self.build_image(document, inner)
          target, alt = image_parts(inner)
          element = document.create_element('img')
          element['src'] = target
          element['alt'] = alt.to_s.empty? ? File.basename(target, '.*') : alt
          element
        end

        #: (Array[Integer], Hash[Symbol, Integer]) -> Range[Integer]
        def self.range_for(offsets, source_position)
          start_line = source_position[:start_line]
          end_line = source_position[:end_line]
          # Commonmarker's +end_column+ is the 1-based column of the *last*
          # byte; an inclusive start column therefore maps to +column - 1+,
          # while the exclusive span end maps to +column+ exactly.
          first = offsets[start_line - 1] + source_position[:start_column] - 1
          last = offsets[end_line - 1] + source_position[:end_column]
          first...last
        end

        # Rebuild the source from typed segments, splicing gaps through the
        # Markdown rewriter.
        #: (String, Array[[Range[Integer], String]]) -> String
        def self.rewrite(source, segments)
          out = +''
          position = 0
          segments.each do |range, content|
            out << rewrite_fragment(source.byteslice(position...range.begin) || '', :markdown)
            out << content
            position = range.end
          end
          out << rewrite_fragment(source.byteslice(position..) || '', :markdown)
          out
        end

        # Rewrite wikilinks in a Markdown source fragment.
        #: (String, Symbol) -> String
        def self.rewrite_fragment(text, mode)
          return text if mode == :code

          text.gsub(WIKILINK_PATTERN) do
            match = Regexp.last_match
            raise 'gsub block without match data' if match.nil?

            inner = match[1].to_s.strip
            if match[0].to_s.start_with?('!') || image_target?(inner)
              render_image(inner, mode)
            else
              render_markdown_anchor(inner)
            end
          end
        end

        # --- Link rendering, Markdown mode

        #: (String) -> String
        def self.render_markdown_anchor(ref)
          href, label = split_ref(ref)
          "[#{escape_markdown_text(label)}](#{escape_markdown_url(href)})"
        end

        #: (String, Symbol) -> String
        def self.render_image(ref, _mode = :markdown)
          target, alt = image_parts(ref)
          alt = File.basename(target, '.*') if alt.to_s.empty?
          "![#{escape_markdown_text(alt)}](#{escape_markdown_url(target)})"
        end

        #: (String) -> [String, String]
        def self.image_parts(ref)
          if ref.include?('|')
            target, caption = ref.split('|', 2).map(&:strip)
            [target.to_s, caption.to_s]
          else
            [ref, File.basename(ref, '.*')]
          end
        end

        #: (String) -> [String, String]
        def self.split_ref(ref)
          if ref.include?('|')
            text, target = ref.split('|', 2).map(&:strip)
            target = target.to_s
            text = text.to_s
            [resolve_link_target(target), text]
          elsif ref.start_with?('#')
            [ref, ref.delete_prefix('#')]
          else
            [resolve_link_target(ref), ref]
          end
        end

        # Link targets are not checked against the actual page set — a
        # wikilink to a missing page renders as a regular link (red-link
        # semantics on the wiki's own page creator). Validation, if ever
        # wanted, belongs at the site layer where the slug catalogue lives.
        #
        # The piped form never special-cases a leading '#': in gollum's one
        # fixed rule the first thing is the display text, so [[#math|Math]]
        # renders [#math](/Math). Anchor handling applies only to the
        # single-part form ([[#anchor]] -> [anchor](#anchor)).
        # Handles [[File.md#anchor]] explicitly: the anchor fragment must
        # survive intact while only the page path component loses .md.
        # A leading '#' is an in-page anchor and passes through unchanged.
        # The path is percent-encoded for URL-unsafe ASCII characters
        # (e.g. "a?b" becomes "a%3Fb") but left as-is for non-ASCII, so
        # links remain human-readable for UTF-8 slugs.
        #: (String) -> String
        def self.resolve_link_target(target)
          return target if target =~ %r{\A[a-z][a-z0-9+.-]*://}i
          return target if target.start_with?('/')
          return target if target.start_with?('#')

          fragment = target.split('#', 2)
          path = fragment[0] || ''
          anchor = fragment[1]
          name = path.end_with?('.md') ? path.sub(/\.md\z/, '') : path
          resolved = "/#{escape_url_path(Slugs.for_title(name))}"
          anchor ? "#{resolved}##{anchor}" : resolved
        end

        # Percent-encodes ASCII characters that are unsafe in a URL path
        # segment; leaves non-ASCII (UTF-8 IRI) characters alone so that
        # Japanese slugs remain readable. Mirrors what a typical SSG/Astro
        # does when generating out/ from the markdown tree.
        #: (String) -> String
        def self.escape_url_path(path)
          path.gsub(/[^\u{80}-\u{10FFFF}A-Za-z0-9\-._~,]/) { |c| format('%%%02X', c.ord) }
        end

        #: (String) -> bool
        def self.image_target?(ref)
          return false if ref.start_with?('#')

          target = ref.include?('|') ? ref.split('|', 2)[0].to_s.strip : ref
          target.match?(IMAGE_EXTENSIONS)
        end

        # --- Escaping

        #: (String) -> String
        def self.escape_html_text(text)
          text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
        end

        #: (String) -> String
        def self.escape_markdown_text(text) = text.gsub('\\', '\\\\').gsub('[', '\\[').gsub(']', '\\]')

        # Markdown link URLs are terminated by a closing parenthesis;
        # angle brackets allow spaces and parens in the destination.
        #: (String) -> String
        def self.escape_markdown_url(url)
          url.include?(')') || url.include?(' ') || url.include?('(') ? "<#{url}>" : url
        end
      end
    end
  end
end
