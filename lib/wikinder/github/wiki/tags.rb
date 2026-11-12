# frozen_string_literal: true
# rbs_inline: enabled

require 'commonmarker'

module Wikinder
  module GitHub
    class Wiki
      # Converts the GitHub Wiki Markdown dialect to standard GFM Markdown.
      #
      # Wikilinks use the double-bracket syntax: [[Page]], [[Page|Display]],
      # [#anchor](#anchor), images reuse the same form: ![[image.png]].
      # Standard Markdown is passed through.
      #
      # Fenced code blocks and inline code spans are preserved verbatim
      # through placeholder exchange so their contents are untouched.
      module Tags
        WIKILINK_PATTERN = /!?\[\[([^\[\]\n]{1,400})\]\]/
        OPEN_PLACEHOLDER = "\x00CODEX_"
        CLOSE_PLACEHOLDER = "_CODEX\x00"

        #: (String) -> String
        def self.render(source)
          offsets = [] #: Array[Integer]
          pos = 0
          source.each_line do |line|
            offsets << pos
            pos += line.bytesize
          end

          ranges = [] #: Array[Range[Integer]]
          Commonmarker.parse(source, options: { extension: { math_dollars: true, math_code: true } }).walk do |node|
            sp = node.source_position
            type = node.type.to_s
            next unless %w[code code_block].include?(type)

            first = offsets[sp[:start_line] - 1] + sp[:start_column] - 1
            last  = offsets[sp[:end_line] - 1] + sp[:end_column]
            ranges << (first...last) if last >= first
          end
          ranges.sort_by!(&:begin)

          markers = {} #: Hash[String, String]
          scratch = +''
          last_end = 0
          ranges.each do |range|
            marker = "#{OPEN_PLACEHOLDER}#{markers.size}#{CLOSE_PLACEHOLDER}"
            markers[marker] = byteslice_range(source, range)
            scratch << byteslice_range(source, last_end...range.begin)
            scratch << marker
            last_end = range.end
          end
          scratch << byteslice_tail(source, last_end)

          # Rewrite any wikilinks / images outside code spans
          scratch = scratch.gsub(WIKILINK_PATTERN) do
            match = Regexp.last_match
            raise 'gsub block without match data' if match.nil?

            inner = match[1].to_s.strip
            if match[0].to_s.start_with?('!')
              render_image(inner)
            else
              render_anchor(inner)
            end
          end

          # Restore code regions verbatim
          markers.each do |marker, verbatim|
            scratch = scratch.gsub(marker, verbatim)
          end

          scratch
        end

        #: (String) -> String
        def self.render_anchor(ref)
          href, label = split_ref(ref)
          "<a href=\"#{escape(href)}\">#{escape(label)}</a>"
        end

        #: (String) -> String
        def self.render_image(ref)
          alt = File.basename(ref, '.*')
          "![#{escape(alt)}](#{escape(ref)})"
        end

        #: (String) -> [String, String]
        def self.split_ref(ref)
          if ref.include?('|')
            parts = ref.split('|', 2).map(&:strip)
            text = parts[0].to_s
            target = parts[1].to_s
            [resolve_link_target(target), text]
          elsif ref.start_with?('#')
            [ref, ref.delete_prefix('#')]
          else
            [resolve_link_target(ref), ref]
          end
        end

        #: (String) -> String
        def self.resolve_link_target(target)
          return target if target =~ %r{\A[a-z][a-z0-9+.-]*://}i
          return target if target.start_with?('/')
          return target if target.start_with?('#')

          name = target.end_with?('.md') ? target.sub(/\.md\z/, '') : target
          slug = Slugs.for_title(name)
          "/#{slug}"
        end

        #: (String, Range[Integer]) -> String
        def self.byteslice_range(source, range)
          source.byteslice(range) or raise 'commonmarker offset out of range'
        end

        #: (String, Integer) -> String
        def self.byteslice_tail(source, start)
          source.byteslice(start..) or ''
        end

        #: (String) -> String
        def self.escape(text) = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
      end
    end
  end
end
