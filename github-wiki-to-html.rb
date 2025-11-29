##
# Main script, intended to be run by `github-wiki-to-html.sh`.
#
# frozen_string_literal: true
#
require 'cgi'
require 'pathname'
require 'uri'

require 'commonmarker'
require 'gollum-lib'
require 'liquid'
require 'nokogiri'

# Load constants.
require_relative 'constants'

# Load methods.
require_relative 'methods'

# Load Gollum configuration.
require_relative 'gollum-config'

# Load the HTML template.
html_template = Liquid::Template.parse(HTML_TEMPLATE_FILE.read, error_mode: :strict2)

# Load the wiki.
wiki = Gollum::Wiki.new(WIKI_REPO.to_s, GOLLUM_OPTIONS)
home_page = wiki.page('Home')
page_footer_html = home_page.footer.formatted_data

# Pages to list on the home page and sitemap file.
all_pages = []

# Generate individual article pages and add them to the list.
wiki.pages.each do |page|
  # Skip non-Markdown pages.
  next unless page.format == :markdown

  slug = page.filename_stripped

  # Skip Home and special pages.
  next if slug =~ /^(?:Home|LICENSE|README)$/

  # Article title.
  main_heading = slug.tr('-', ' ')

  encoded_slug = URI.encode_uri_component(slug)

  # URL of the page on the converted site.
  canonical_url = SITE_URL_SLASH.merge(encoded_slug)

  # URL of the page on the wiki.
  wiki_page_url = WIKI_URL_SLASH.merge(encoded_slug)

  # Get the oldest commit of the page (following renames).
  oldest_commit = page.versions({
    follow: true,
    per_page: 100_000,
  }).last

  # Get the latest commit of the page.
  latest_commit = page.last_version

  is_modified = latest_commit.id != oldest_commit.id

  # Published date in UTC.
  published_date = oldest_commit.authored_date.getutc
  published_date_iso = published_date.iso8601
  published_date_display = published_date.strftime(DISPLAY_DATE_FORMAT)

  # Last modified date in UTC.
  modified_date = latest_commit.authored_date.getutc
  modified_date_iso = modified_date.iso8601
  modified_date_display = modified_date.strftime(DISPLAY_DATE_FORMAT)

  # Name of the author of the oldest commit.
  author_name = oldest_commit.author.name

  # URL of the oldest commit in the mirror repo.
  author_url = MIRROR_REPO_URL_SLASH.merge("commit/#{oldest_commit.id}")

  # Generate the HTML file for the article.
  generate_html_file("#{slug}.html", page.formatted_data, html_template, {
    is_home: false,
    canonical_url: canonical_url.to_s,
    wiki_page_url: wiki_page_url.to_s,
    main_heading:,
    page_footer_html:,

    is_modified:,
    published_date_iso:,
    published_date_display:,
    modified_date_iso:,
    modified_date_display:,

    author_name:,
    author_url: author_url.to_s,
  })

  # Add the page to the list.
  all_pages << {
    url: Pathname(HOME_URL_SLASH).join(encoded_slug).to_s,
    canonical_url:,
    title: main_heading,
    published_date:,
    modified_date:,
    modified_date_iso:,
  }
end

# Pages sorted by published date (newest first).
pages_by_published_date = all_pages
  .reject { |page| page[:title].start_with?(SITE_NAME) } # Exclude About pages.
  .sort_by { |page| page[:published_date] }
  .reverse

# Generate the HTML file for the home page.
generate_html_file('index.html', home_page.formatted_data, html_template, {
  is_home: true,
  canonical_url: SITE_URL.to_s,
  wiki_page_url: WIKI_URL.to_s,
  main_heading: HOME_HEADING,
  page_footer_html:,

  all_pages: pages_by_published_date,
})

# Pages sorted by modified date (newest first).
pages_by_modified_date = all_pages
  .sort_by { |page| page[:modified_date] }
  .reverse

# Generate the sitemap file.
generate_sitemap_file(pages_by_modified_date)
