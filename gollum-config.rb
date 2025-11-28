##
# Configuration for Gollum
#

# Options for the Gollum::Wiki constructor
GOLLUM_OPTIONS = {
  # Base path for internal links
  base_path: BASE_PATH.to_s,

  # Convert spaces to hyphens in internal links
  hyphened_tag_lookup: true,

  # Do not add class="editable" to section headings
  allow_editing: false,

  # Keep Gollum's filter chain minimal
  # :Tags - Convert internal links to standard Markdown links
  # :Render - Render Markdown to HTML
  filter_chain: [:Tags, :Render],
}

# Use Commonmarker as the Markdown renderer
GitHub::Markup::Markdown::MARKDOWN_GEMS.clear
GitHub::Markup::Markdown::MARKDOWN_GEMS['commonmarker'] = proc do |markdown|
  ::Commonmarker.to_html(markdown, options: {
    render: {
      # Allow raw HTML tags to support <details> tags etc.
      unsafe: true,
    },
    extension: {
      # Remove blacklisted HTML tags (GFM)
      tagfilter: true,

      # Enable footnote syntax (GFM)
      footnotes: true,
    },
  })
end
