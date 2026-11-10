# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'code_regions'
require 'gollum-lib'

module Gollum
  class Filter
    # Gollum tag extraction restricted to non-code regions.
    # Gollum itself skips tags inside <code> elements after it has rendered
    # to HTML; since the passthrough renderer does not render, code regions
    # must be recognized here instead.
    class AstTags < Tags
      #: (String) -> String
      def extract(data)
        Wikinder::GitHub::Wiki::CodeRegions.process_regions(data) { |seg, code| code ? seg : super(seg) }
      end

      # String-based replacement; keeps the document byte-identical
      # apart from placeholders (gollum's HTML-tree walk would mangle it).
      # Tags outside code are resolved; inside code they stay literal.
      #: (String) -> String
      def process(data)
        Wikinder::GitHub::Wiki::CodeRegions.process_regions(data) { |seg, code| substitute(seg, code) }
      end

      private

      # Returns a GFM link, preserving the kind of link gollum resolved.
      #: (String, String?, String?, Symbol?) -> String
      def generate_link(path, name = nil, extra = nil, kind = nil)
        url = kind == :external ? path : generate_href_for_path(path, extra)
        text = name || path
        kind == :internal_anchor ? "[#{text}](##{extra})" : "[#{text}](#{url})"
      end

      # Returns a GFM image, dropping image options gollum would have applied.
      #: (String, Hash[Symbol, untyped]?) -> String
      def generate_image(path, options = nil)
        alt = options&.[](:alt) || ::File.basename(path)
        "![#{alt}](#{path})"
      end

      # Generates a normalized site href for wiki paths.
      # Strips .md extensions and encodes spaces as hyphens.
      #: (String, String?) -> String
      def generate_href_for_path(path, extra = nil)
        return extra.to_s if !path && extra

        ext = ::File.extname(path.to_s)
        clean = ::File.join(@markup.wiki.base_path, path)
        clean = clean.sub(/#{Regexp.escape(ext)}$/, '') if ext == '.md'
        "#{clean.gsub('%20', '-')}#{extra}"
      end

      # Replaces placeholders with resolved tags, or literal text when code.
      #: (String, bool) -> String
      def substitute(seg, code)
        seg.gsub(/#{open_pattern}[a-f0-9]+#{close_pattern}/) do |id|
          tag = @map[id]
          if tag.nil?
            id
          elsif code
            "[[#{tag}]]"
          else
            process_tag(tag).gsub('%2f', '/')
          end
        end
      end
    end
  end
end
