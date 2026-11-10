# frozen_string_literal: true
# rbs_inline: enabled

require 'gollum-lib'

module Gollum
  class Filter
    # Resolves wiki markup by emitting HTML anchors for the output.
    # Gollum keeps running in its own domain (page lookup, link kinds,
    # anchor handling); only the output shape changes.
    #
    # Plain text inside raw HTML blocks requires raw HTML anchors:
    # Astro's Markdown pipeline does not parse GFM links inside HTML
    # markup, so a `[[Page]]` inside e.g. `<td>` would stay literal.
    # Emitting HTML anchors everywhere keeps behavior uniform.
    class AstTags < Tags
      # Substitutes tag placeholders with their resolved forms.
      #: (String) -> String
      def process(data)
        data.gsub(/#{open_pattern}[a-f0-9]+#{close_pattern}/) do |id|
          tag = @map[id]
          tag.nil? ? id : process_tag(tag).gsub(/%2f/i, '/')
        end
      end

      # Resolves a file/image attachment reference.
      # Uses GFM-safe escaped path (spaces -> %20) for attachments,
      # matching how Gollum emits hrefs for file links.
      #: (String, String?) -> String?
      def process_file_link_tag(link_part, pretty_name)
        return nil if ::Gollum::Page.valid_extension?(link_part)
        return unless (file = find_page_or_file_from_path(link_part, :file))

        generate_link(file.escaped_url_path, pretty_name, nil, :file)
      end

      #: (String, String?) -> String
      def process_image_tag(path, options = nil)
        opts = parse_image_tag_options(options)

        if path =~ %r{^https?://.+$}i
          generate_image(path, opts)
        elsif (file = find_page_or_file_from_path(path, :file))
          alt = opts[:alt] || ::File.basename(file.url_path)
          generate_image(generate_href_for_path(file.escaped_url_path), opts.merge(alt: alt))
        else
          generate_image('', opts)
        end
      end

      ESC_TEXT = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;' }.freeze #: Hash[String, String]
      ESC_ATTR = ESC_TEXT.merge('"' => '&quot;', "'" => '&#39;').freeze #: Hash[String, String]

      private

      # Escapes the text content of an HTML anchor.
      #: (String) -> String
      def escape_link_text(text) = text.gsub(/[&<>]/, ESC_TEXT)

      # Returns an HTML anchor, preserving the kind of link gollum resolved.
      # Plain text inside raw HTML blocks needs raw HTML; GFM links would
      # stay literal inside HTML markup, so we emit HTML anchors everywhere
      # (Astro's Markdown renderer understands raw HTML inline and the GFM
      # anchor form does not work inside raw HTML blocks).
      #: (String, String?, String?, Symbol?) -> String
      def generate_link(path, name = nil, extra = nil, kind = nil)
        url = kind == :external ? path : generate_href_for_path(path, extra)
        raw_text = name || path || extra.to_s.delete_prefix('#')
        text = escape_link_text(raw_text)
        href = url.to_s.gsub(/[&<>"']/, ESC_ATTR)
        "<a href=\"#{href}\">#{text}</a>"
      end

      # Returns a GFM image, dropping image options gollum would have applied.
      #: (String, Hash[Symbol, untyped]?) -> String
      def generate_image(path, options = nil)
        alt = options&.[](:alt) || ::File.basename(path)
        "![#{alt}](#{path})"
      end

      # Generates a normalized site href for wiki paths.
      # Page slugs (.md stripped) and extensionless tag lookups both
      # hyphenate spaces, since GitHub Wiki page filenames follow the
      # `page-name.md` convention. Attachment paths (e.g. `.png` files)
      # keep their escaped URL as-is so the raw path is preserved.
      #: (String?, ?String?) -> String
      def generate_href_for_path(path, extra = nil)
        return extra if !path && extra

        ext = ::File.extname(path.to_s)
        is_page = ext.empty? || ext.casecmp('.md').zero?
        stripped = path.to_s.sub(/\.md\z/i, '')
        url = super(stripped, nil)
        url = url.gsub('%20', '-') if is_page
        "#{url}#{extra}"
      end
    end
  end
end
