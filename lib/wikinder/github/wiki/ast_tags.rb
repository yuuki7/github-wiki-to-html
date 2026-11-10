# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'

module Gollum
  class Filter
    # Resolves wiki markup by emitting standard GFM Markdown, not
    # HTML. Gollum keeps running in its own domain (page lookup, link
    # kinds, anchor handling); only the output shape changes.
    #
    # Tags outside code regions have already been withdrawn by the
    # filters before this one; the rest of the substitution stays a
    # string operation, since an HTML-tree walk would mangle Markdown.
    class AstTags < Tags
      # Substitutes tag placeholders with their resolved forms.
      #: (String) -> String
      def process(data)
        data.gsub(/#{open_pattern}[a-f0-9]+#{close_pattern}/) do |id|
          tag = @map[id]
          tag.nil? ? id : process_tag(tag).gsub(/%2f/i, '/')
        end
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
      # Strips .md extensions, decodes path slashes, and encodes
      # spaces as hyphens. Anchor-only links come through untouched.
      #: (String?, String?) -> String
      def generate_href_for_path(path, extra = nil)
        return extra if !path && extra

        super(path.to_s.sub(/\.md\z/, ''), nil).gsub('%20', '-') + extra.to_s
      end
    end
  end
end
