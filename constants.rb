##
# Constants for use in the main script.
#
# frozen_string_literal: true
#

##
# Constants for the GitHub Wiki.
#

# Local path to the cloned wiki repository.
WIKI_REPO = Pathname('wikinder.wiki')

# Full URL of the wiki.
WIKI_URL = URI('https://github.com/wikinder/wikinder/wiki')

# Wiki URL with a trailing slash for path handling.
WIKI_URL_SLASH = URI("#{WIKI_URL.to_s.delete_suffix('/')}/")

##
# Constants for the converted site.
#

# Local path to the output directory.
OUTPUT_DIRECTORY = Pathname('wikinder.github.io')

# Title of the site.
SITE_NAME = 'Wikinder'

# Full URL of the site.
SITE_URL = URI('https://wikinder.org')

# Site URL with a trailing slash for path handling.
SITE_URL_SLASH = URI("#{SITE_URL.to_s.delete_suffix('/')}/")

# Name of the publisher.
PUBLISHER_NAME = 'Wikinder'

# Full URL of the publisher.
PUBLISHER_URL = URI('https://wikinder.org')

# Full URL of the publisher's logo.
PUBLISHER_LOGO_URL = SITE_URL_SLASH.merge('/assets/images/icon.jpg')

# Heading of the home page.
HOME_HEADING = "Welcome to #{SITE_NAME}"

# Root-relative URL of the home page.
HOME_URL = URI(SITE_URL.request_uri)

# Home URL with a trailing slash for path handling.
HOME_URL_SLASH = URI("#{HOME_URL.to_s.delete_suffix('/')}/")

# URL of the stylesheet.
STYLESHEET_URL = URI('/assets/css/style.css')

# URL of the MathJax configuration script.
MATHJAX_CONFIG_SCRIPT_URL = URI('/assets/js/mathjax-config.js')

# Local path to the HTML template file.
HTML_TEMPLATE_FILE = Pathname('template.html.liquid')

# Date format for article headers.
DISPLAY_DATE_FORMAT = '%B %-d, %-Y'
