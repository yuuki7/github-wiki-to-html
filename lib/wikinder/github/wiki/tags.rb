# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'
require 'nokogiri'
require 'nokogiri/html5'
require 'securerandom'

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
      # them. All raw HTML blocks of a page are parsed together as a single
      # HTML5 stream (Nokogiri), because constructs such as <details>
      # routinely span several blocks separated by blank lines — parsing
      # each block in isolation would auto-close elements that a later
      # block closes and drop their closing tags. Wikilinks in text nodes
      # are rewritten as raw HTML anchors; everything else is reserialized
      # by the parser, which normalizes the markup (supplying an implied
      # <tbody>, for example) rather than preserving the source bytes.
      module Tags
        # Elements treated as raw text by HTML5 — their contents are not
        # recursively parsed, so wikilinks there must not be rewritten.
        RAW_TEXT_ELEMENTS = %w[script style textarea title].freeze #: Array[String]
        TOC_LITERALS = %w[_TOC_ __TOC__].freeze #: Array[String]
        # No length cap on the tag body: gollum sets none, and the label of
        # a piped link can legitimately run long. The negated class keeps
        # the scan linear, and a match can never span lines.
        WIKILINK_PATTERN = /!?\[\[([^\[\]\n]+)\]\]/
        IMAGE_EXTENSIONS = /\.(png|jpe?g|gif|webp|svg)([?#].*)?\z/i

        # Converts one page of GitHub Wiki Markdown to standard
        # GFM Markdown.
        #: (String, ?link_index: link_index?, ?routes: link_routes?) -> String
        def self.render(source, link_index: nil, routes: nil)
          offsets = line_offsets(source)
          resolver = LinkResolver.new(link_index, routes)
          segments = typed_ranges(source, offsets, resolver)
          rewrite(source, segments, resolver)
        end

        # Builds the lookup used to canonicalize link targets against a
        # wiki's actual pages and files. Each map holds every name under
        # its exact spelling first and then under a folded key (spaces
        # become hyphens, compared case-insensitively), mirroring how
        # GitHub Wiki resolves internal links: [[my page]] and [[MY-PAGE]]
        # both find the page whose file is "My-Page.md", and the link is
        # emitted with the found page's own spelling. Names that collide
        # only after folding keep the first page in the order given.
        #: (Array[String], Array[String]) -> Hash[Symbol, Hash[String, String]]
        def self.build_link_index(page_slugs, asset_names)
          {
            pages: build_name_index(page_slugs),
            files: build_name_index(asset_names)
          }
        end

        #: (Array[String]) -> Hash[String, String]
        def self.build_name_index(names)
          index = {} #: Hash[String, String]
          names.each do |name|
            index[name] = name
            index[fold_key(name)] ||= name
          end
          index
        end

        # The folded comparison key: spaces become hyphens and case is
        # folded, as in gollum's path_compare with its hyphened and
        # case-insensitive tag lookups enabled.
        #: (String) -> String
        def self.fold_key(name)
          name.gsub(' ', '-').downcase
        end

        # Exact spelling wins; the folded key is the fallback.
        #: (Hash[String, String], String) -> String?
        def self.index_lookup(index, name)
          index[name] || index[fold_key(name)]
        end

        # Resolves the wikilinks of one page render against the
        # wiki's link index and the routes of the language being
        # rendered. The index and the routes are fixed for a whole
        # page, so the rewriting pipeline carries one resolver
        # instead of threading the pair through every step; only
        # what varies from link to link is passed along.
        class LinkResolver
          # @rbs @link_index: link_index?
          # @rbs @routes: link_routes?

          #: (link_index?, link_routes?) -> void
          def initialize(link_index, routes)
            @link_index = link_index
            @routes = routes
          end

          # Whether a target is an image is decided by its extension
          # alone — in gollum the leading '!' is not an image marker at
          # all. It is consumed when the target is an image (the usual
          # embed spelling); before a page link it stays as literal text,
          # so ![[Page]] renders as "!" followed by a link to Page.
          #: (Nokogiri::XML::Document, MatchData) -> Array[Nokogiri::XML::Node]
          def build_elements(document, match)
            inner = match[1].to_s.strip
            if Tags.toc_literal?(inner)
              [Nokogiri::XML::Text.new(match[0].to_s, document)]
            elsif Tags.image_target?(inner)
              [build_image(document, inner)]
            elsif match[0].to_s.start_with?('!')
              [Nokogiri::XML::Text.new('!', document), build_anchor(document, inner)]
            else
              [build_anchor(document, inner)]
            end
          end

          #: (Nokogiri::XML::Document, String) -> Nokogiri::XML::Node
          def build_anchor(document, inner)
            href, label = split_ref(inner)
            element = document.create_element('a')
            element['href'] = href
            element.content = label
            element
          end

          #: (Nokogiri::XML::Document, String) -> Nokogiri::XML::Node
          def build_image(document, inner)
            target, alt = Tags.image_parts(inner)
            target = canonical_file_name(target)
            element = document.create_element('img')
            element['src'] = target
            element['alt'] = alt.to_s.empty? ? File.basename(target, '.*') : alt
            element
          end

          # --- Link rendering, Markdown mode

          #: (String) -> String
          def render_markdown_anchor(ref)
            href, label = split_ref(ref)
            "[#{Tags.escape_markdown_text(label)}](#{Tags.escape_markdown_url(href)})"
          end

          #: (String) -> String
          def render_image(ref)
            target, alt = Tags.image_parts(ref)
            target = canonical_file_name(target)
            alt = File.basename(target, '.*') if alt.to_s.empty?
            "![#{Tags.escape_markdown_text(alt)}](#{Tags.escape_markdown_url(target)})"
          end

          # Only the first two pipe segments are used, as in gollum's
          # parse_tag_parts; anything past the second is discarded, and a
          # trailing empty segment disappears with the split, so
          # [[Page|]] is an ordinary link to Page.
          #: (String) -> [String, String]
          def split_ref(ref)
            parts = ref.split('|').map(&:strip)
            if parts.size >= 2
              text = parts[0].to_s
              target = parts[1].to_s
              [resolve_link_target(target), text]
            else
              single = parts[0].to_s
              if single.start_with?('#')
                [single, single.delete_prefix('#')]
              else
                [resolve_link_target(single), single]
              end
            end
          end

          # When the caller supplies the wiki's link index, a target
          # that names an existing page is canonicalized to that
          # page's own spelling. GitHub Wiki resolves internal links
          # leniently (spaces and hyphens folded, case-insensitive),
          # so the written form need not match the file name. A target
          # that matches nothing is rendered as a regular link in its
          # written form: marking missing pages (Gollum's "absent"
          # class in HTML output) has no place in Markdown output
          # and belongs, if anywhere, to the site layer.
          #
          # The piped form never special-cases a leading '#': in
          # gollum's one fixed rule the first part is the display
          # text, so [[#math|Math]] renders as [#math](/Math). Anchor
          # handling applies only to the single-part form ([[#anchor]]
          # becomes [anchor](#anchor)). In [[File.md#anchor]] only
          # the page part loses its .md; the fragment survives intact.
          #
          # When the caller supplies +routes+, the link takes the
          # prefix routes give for the target's slug (see
          # Wiki#routes_by_language). Without routes, the historical
          # root-relative form is kept.
          #: (String) -> String
          def resolve_link_target(target)
            return target if target =~ %r{\A[a-z][a-z0-9+.-]*://}i
            return target if target.start_with?('/')
            return target if target.start_with?('#')

            link_index = @link_index
            routes = @routes
            fragment = target.split('#', 2)
            path = fragment[0] || ''
            anchor = fragment[1]
            name = path.end_with?('.md') ? path.sub(/\.md\z/, '') : path
            canonical = link_index && Tags.index_lookup(link_index[:pages], name)
            slug = canonical || Slugs.for_title(name)
            prefix = routes && (routes[slug] || (canonical && routes[canonical]))
            resolved = prefix ? "#{prefix}/#{Tags.escape_url_path(slug)}" : "/#{Tags.escape_url_path(slug)}"
            anchor ? "#{resolved}##{anchor}" : resolved
          end

          # Canonicalizes an image/file target against the link index, the
          # same lenient lookup pages get; unmatched targets pass through
          # as written.
          #: (String) -> String
          def canonical_file_name(target)
            link_index = @link_index
            return target if link_index.nil?
            return target if target =~ %r{\A[a-z][a-z0-9+.-]*://}i
            return target if target.start_with?('/')

            Tags.index_lookup(link_index[:files], target) || target
          end
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
        #: (String, Array[Integer], LinkResolver) -> Array[[Range[Integer], String]]
        def self.typed_ranges(source, offsets, resolver)
          ranges = [] #: Array[[Range[Integer], String]]
          html_blocks = [] #: Array[[Range[Integer], String]]
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
              html_blocks << [sp_range, source.byteslice(sp_range).to_s]
            end
          end
          rewritten_blocks = rewrite_html_stream(html_blocks.map { |_range, text| text }, resolver)
          rewritten_blocks.each_with_index do |rewritten, index|
            range, _text = html_blocks[index]
            ranges << [range, rewritten] if range
          end
          ranges.sort_by! { |range, _replacement| range.begin }
          ranges
        end

        # Rewrites wikilinks in a page's raw HTML blocks. The blocks are
        # joined with unique comment markers and parsed as one HTML5
        # stream, so an element opened in one block can be closed in a
        # later one; after rewriting, the stream is split at the markers
        # again. Content the parser moved across a marker (an unclosed
        # element before the first block, auto-closures after the last)
        # is added to the nearest block. If a marker does not survive
        # the round trip — a <script> spanning several blocks can hold
        # it as raw text, so it is no longer a comment — each block is
        # rewritten on its own instead, so the result is never worse
        # than per-block parsing.
        #: (Array[String], LinkResolver) -> Array[String]
        def self.rewrite_html_stream(blocks, resolver)
          return [] if blocks.empty?

          marker = gap_marker(blocks)
          stream = +''
          blocks.each_with_index { |text, index| stream << "<!--#{marker}:#{index}-->" << text }
          stream << "<!--#{marker}:#{blocks.size}-->"
          fragment = parse_fragment(stream)
          rewrite_fragment_text_nodes(fragment, resolver)
          pieces = split_stream(fragment.to_html, marker, blocks.size)
          return blocks.map { |text| rewrite_html_block(text, resolver) } if pieces.nil?

          pieces
        end

        # Splits a serialized HTML stream at the gap markers, returning one
        # string per original block, or nil when the markers did not all
        # survive in order.
        #: (String, String, Integer) -> Array[String]?
        def self.split_stream(serialized, marker, count)
          parts = serialized.split(/<!--#{Regexp.escape(marker)}:(\d+)-->/, -1)
          return nil unless parts.size == (2 * count) + 3
          return nil unless (1...parts.size).step(2).map { |i| parts[i].to_i } == (0..count).to_a

          pieces = (0...count).map { |index| parts[(2 * index) + 2].to_s }
          pieces[0] = "#{parts[0]}#{pieces[0]}"
          pieces[count - 1] = "#{pieces[count - 1]}#{parts[(2 * count) + 2]}"
          pieces
        end

        # A comment token that appears in none of the blocks, so joining
        # blocks with it cannot collide with page content.
        #: (Array[String]) -> String
        def self.gap_marker(blocks)
          marker = 'wikinder-gap'
          marker = "#{marker}-#{SecureRandom.hex(4)}" while blocks.any? { |text| text.include?(marker) }
          marker
        end

        #: (String) -> Nokogiri::XML::DocumentFragment
        def self.parse_fragment(text)
          Nokogiri::HTML5.fragment(text.dup.force_encoding(Encoding::UTF_8))
        end

        # Rewrites wikilinks in the text nodes of a parsed fragment.
        # Raw-text element contents (script, style, textarea, title) are
        # left verbatim, as are attribute values.
        #: (Nokogiri::XML::DocumentFragment, LinkResolver) -> void
        def self.rewrite_fragment_text_nodes(fragment, resolver)
          fragment.traverse do |node|
            next unless node.text?
            next if inside_raw_text?(node)

            split_and_replace_wikilinks(node, resolver)
          end
        end

        # Rewrites wikilinks in a single HTML block: parses with Nokogiri,
        # splits each text node at wikilinks, producing anchor/image
        # elements. Used for pages whose blocks cannot be joined (see
        # rewrite_html_stream).
        #: (String, LinkResolver) -> String
        def self.rewrite_html_block(fragment_text, resolver)
          fragment = parse_fragment(fragment_text)
          rewrite_fragment_text_nodes(fragment, resolver)
          fragment.to_html
        end

        #: (Nokogiri::XML::Node) -> bool
        def self.inside_raw_text?(node)
          node.ancestors.any? { |ancestor| RAW_TEXT_ELEMENTS.include?(ancestor.name.downcase) }
        end

        # Splits a text node at its wikilinks, replacing it with
        # the text and element nodes the links produce.
        #: (Nokogiri::XML::Node, LinkResolver) -> void
        def self.split_and_replace_wikilinks(node, resolver)
          text = node.content
          return unless text.include?('[[')

          document = node.document
          nodes = [] #: Array[Nokogiri::XML::Node]
          rest = text.dup
          while (match = rest.match(WIKILINK_PATTERN))
            pre = rest[0...match.begin(0)]
            nodes << Nokogiri::XML::Text.new(pre, document) if pre.is_a?(String) && !pre.empty?

            nodes.concat(resolver.build_elements(document, match))
            rest = rest[match.end(0)..]
          end
          nodes << Nokogiri::XML::Text.new(rest, document) if rest.is_a?(String) && !rest.empty?
          return if nodes.empty?

          node.replace(Nokogiri::XML::NodeSet.new(document, nodes))
        end

        # GitHub Wiki leaves [[_TOC_]] and [[__TOC__]] unconverted —
        # they render as literal brackets around emphasized text — so
        # the converter passes them through untouched rather than
        # turning them into links.
        #: (String) -> bool
        def self.toc_literal?(inner)
          TOC_LITERALS.include?(inner)
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
        #: (String, Array[[Range[Integer], String]], LinkResolver) -> String
        def self.rewrite(source, segments, resolver)
          out = +''
          position = 0
          segments.each do |range, content|
            out << rewrite_fragment(source.byteslice(position...range.begin) || '', resolver)
            out << content
            position = range.end
          end
          out << rewrite_fragment(source.byteslice(position..) || '', resolver)
          out
        end

        # Rewrite wikilinks in a Markdown source fragment.
        #: (String, LinkResolver) -> String
        def self.rewrite_fragment(text, resolver)
          text.gsub(WIKILINK_PATTERN) do
            match = Regexp.last_match
            raise 'gsub block without match data' if match.nil?

            inner = match[1].to_s.strip
            if toc_literal?(inner)
              match[0].to_s
            elsif image_target?(inner)
              resolver.render_image(inner)
            elsif match[0].to_s.start_with?('!')
              # The output is itself Markdown, so a bare '!' in front of
              # the link would be re-parsed downstream as an image. The
              # escape keeps it the literal text GitHub renders.
              "\\!#{resolver.render_markdown_anchor(inner)}"
            else
              resolver.render_markdown_anchor(inner)
            end
          end
        end

        # Gollum reads the part after the pipe as image options
        # (width=100, frame, and so on). Standard Markdown cannot
        # express them, so the converter uses that part as the
        # image's alt text instead of dropping it. Segments past the
        # second are ignored, as in gollum's parse_tag_parts.
        #: (String) -> [String, String]
        def self.image_parts(ref)
          parts = ref.split('|').map(&:strip)
          if parts.size >= 2
            [parts[0].to_s, parts[1].to_s]
          else
            target = parts[0].to_s
            [target, File.basename(target, '.*')]
          end
        end

        # Percent-encodes ASCII characters that are unsafe in a URL
        # path segment. Non-ASCII (UTF-8 IRI) characters are left
        # alone, so Japanese slugs remain readable.
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
