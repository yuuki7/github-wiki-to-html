##
# Methods for use in the main script.
#
# frozen_string_literal: true
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
    home_url: HOME_URL.to_s,
    publisher_name: PUBLISHER_NAME,
    publisher_url: PUBLISHER_URL.to_s,
    publisher_logo_url: PUBLISHER_LOGO_URL.to_s,
    stylesheet_url: STYLESHEET_URL.to_s,
    mathjax_config_script_url: MATHJAX_CONFIG_SCRIPT_URL.to_s,
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

# Generate a sitemap file.
def generate_sitemap_file(pages)
  xml = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{SITE_URL}</loc>
      </url>
  XML

  pages.each do |page|
    xml << <<~XML % page
      <url>
        <loc>%{canonical_url}</loc>
        <lastmod>%{modified_date_iso}</lastmod>
      </url>
    XML
  end

  xml << '</urlset>'

  sitemap_file = OUTPUT_DIRECTORY.join('sitemap.xml')
  sitemap_file.write(xml)
end
