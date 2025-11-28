##
# Methods for use in the main script.
#

# Tweak HTML converted from Markdown
def postprocess_html(html)
  dom = Nokogiri::HTML5.fragment(html)

  # Handle links with class="internal"
  dom.css('a.internal').each do |a|
    uri = URI(a['href'])
    path = Pathname(uri.path)

    # Strip the extension
    path = path.sub_ext('')

    # Make the path relative
    path = path.relative_path_from(BASE_PATH)

    uri.path = path.to_s
    a['href'] = uri.to_s
  end

  dom.to_html
end

# Generate an HTML file
def generate_html_file(output_filename, article_body_html, html_template, options)
  article_body_html = postprocess_html(article_body_html)

  # Render full HTML
  full_html = html_template.render!({
    site_url: SITE_URL.to_s,
    site_name: SITE_NAME,
    base_path: BASE_PATH.to_s,
    logo_url: LOGO_URL.to_s,
    stylesheet_file: STYLESHEET_FILE.to_s,
    mathjax_config_script: MATHJAX_CONFIG_SCRIPT.to_s,
    article_body: article_body_html,
    **options
  }.transform_keys(&:to_s), {
    strict_variables: true,
    strict_filters: true,
  })

  # Write HTML to a file
  output_file = OUTPUT_DIRECTORY.join(output_filename)
  output_file.write(full_html)
end
