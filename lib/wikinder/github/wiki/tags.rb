# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'

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
      # them. References inside code spans, code blocks, math spans, and
      # raw HTML blocks are handled separately from the rest of the document.
      module Tags
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

        # Typed ranges: :code (verbatim) or :html (rewrite as raw HTML).
        # Tag syntax inside raw HTML blocks is protected by PROTECTED_HTML
        # (script/comment/style bodies included); inline tags anywhere are
        # protected as html_inline code ranges below.
        #: Regexp
        PROTECTED_HTML = %r{<!--.*?-->|<script\b[^>]*>.*?</script>|<style\b[^>]*>.*?</style>|<[a-zA-Z/!?][^>]*>}im

        #: (String, Array[Integer]) -> Array[[Range[Integer], Symbol]]
        def self.typed_ranges(source, offsets)
          ranges = [] #: Array[[Range[Integer], Symbol]]
          Commonmarker.parse(source, options: { extension: { math_dollars: true, math_code: true } }).walk do |node|
            type = node.type.to_s
            sp = node.source_position
            case type
            when 'code', 'code_block', 'math', 'html_inline'
              # Inline tags stay verbatim (with their attributes); their
              # inner text runs through the normal Markdown pipeline.
              ranges << [range_for(offsets, sp), :code]
            when 'html_block'
              html_fragments(source, range_for(offsets, sp)).each { |fragment, mode| ranges << [fragment, mode] }
            end
          end
          ranges.sort_by! { |range, _| [range.begin, range.end] }
          ranges
        end

        # Splits an html_block range into :code subranges (comments,
        # script/style bodies, individual tags with their attributes) and
        # :html gaps between them. Everything inside a tag — including its
        # attributes — stays verbatim; wiki syntax in text between tags is
        # rewritten as raw HTML anchors.
        #: (String, Range[Integer]) -> Array[[Range[Integer], Symbol]]
        def self.html_fragments(source, html_range)
          fragments = [] #: Array[[Range[Integer], Symbol]]
          # Work on raw bytes so regex match offsets are byte offsets —
          # matching UTF-8 text would yield character offsets, corrupting
          # multibyte content.
          block = (source.byteslice(html_range) || '').dup.force_encoding(Encoding::BINARY)
          cursor = 0

          block.to_enum(:scan, PROTECTED_HTML).each do
            match = Regexp.last_match
            next if match.nil?

            guard_start = match.begin(0) || 0
            guard_end = match.end(0) || 0
            next_start = html_range.begin + guard_start
            fragments << [(html_range.begin + cursor)...next_start, :html] if guard_start > cursor
            fragments << [(html_range.begin + guard_start)...(html_range.begin + guard_end), :code]
            cursor = guard_end
          end
          fragments << [(html_range.begin + cursor)...html_range.end, :html] if cursor < block.length
          fragments
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

        # Rebuild the source from typed segments, rewriting links in the gaps.
        #: (String, Array[[Range[Integer], Symbol]]) -> String
        def self.rewrite(source, segments)
          out = +''
          position = 0
          segments.each do |range, mode|
            next if range.end <= position # nested segment, already covered

            out << rewrite_fragment(source.byteslice(position...range.begin) || '', :markdown)
            out << rewrite_fragment(source.byteslice(range) || '', mode)
            position = range.end
          end
          out << rewrite_fragment(source.byteslice(position..) || '', :markdown)
          out
        end

        # Rewrite wikilinks in a source fragment.
        #: (String, Symbol) -> String
        def self.rewrite_fragment(text, mode)
          return text if mode == :code

          text.gsub(WIKILINK_PATTERN) do
            match = Regexp.last_match
            raise 'gsub block without match data' if match.nil?

            inner = match[1].to_s.strip
            if match[0].to_s.start_with?('!') || image_target?(inner)
              render_image(inner, mode)
            elsif mode == :html
              render_html_anchor(inner)
            else
              render_markdown_anchor(inner)
            end
          end
        end

        # --- Link rendering

        #: (String) -> String
        def self.render_markdown_anchor(ref)
          href, label = split_ref(ref)
          "[#{escape_markdown_text(label)}](#{escape_markdown_url(href)})"
        end

        #: (String) -> String
        def self.render_html_anchor(ref)
          href, label = split_ref(ref)
          "<a href=\"#{escape_attr(href)}\">#{escape_html_text(label)}</a>"
        end

        # Images keep the same shape in both modes.
        #: (String, Symbol) -> String
        def self.render_image(ref, mode)
          target, alt = image_parts(ref)
          alt = File.basename(target, '.*') if alt.to_s.empty?
          if mode == :html
            "<img src=\"#{escape_attr(target)}\" alt=\"#{escape_attr(alt)}\" />"
          else
            "![#{escape_markdown_text(alt)}](#{escape_markdown_url(target)})"
          end
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
        #: (String) -> String
        def self.resolve_link_target(target)
          return target if target =~ %r{\A[a-z][a-z0-9+.-]*://}i
          return target if target.start_with?('/')
          return target if target.start_with?('#')

          fragment = target.split('#', 2)
          path = fragment[0] || ''
          anchor = fragment[1]
          name = path.end_with?('.md') ? path.sub(/\.md\z/, '') : path
          resolved = "/#{Slugs.for_title(name)}"
          anchor ? "#{resolved}##{anchor}" : resolved
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
        def self.escape_attr(text) = escape_html_text(text)

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
