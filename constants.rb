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

WIKI_URL_SLASH = URI("#{WIKI_URL.to_s.delete_suffix('/')}/")

# Full URL of the GitHub repository where the wiki is mirrored.
MIRROR_REPO_URL = URI('https://github.com/wikinder/wikinder')

MIRROR_REPO_URL_SLASH = URI("#{MIRROR_REPO_URL.to_s.delete_suffix('/')}/")

##
# Constants for the converted site.
#

# Local path to the output directory.
OUTPUT_DIRECTORY = Pathname('wikinder.github.io')

# Local path to the HTML template file.
HTML_TEMPLATE_FILE = Pathname('template.html.liquid')

# Title of the site.
SITE_NAME = 'Wikinder'

ESCAPED_SITE_NAME = CGI.escape_html(SITE_NAME)

# Full URL of the site.
SITE_URL = URI('https://wikinder.org')

SITE_URL_SLASH = URI("#{SITE_URL.to_s.delete_suffix('/')}/")

# Name of the publisher.
PUBLISHER_NAME = 'Wikinder'

ESCAPED_PUBLISHER_NAME = CGI.escape_html(PUBLISHER_NAME)

# Full URL of the publisher.
PUBLISHER_URL = URI('https://wikinder.org')

# Full URL of the publisher's logo.
PUBLISHER_LOGO_URL = SITE_URL_SLASH.merge('/assets/images/icon.jpg')

# Heading of the home page.
HOME_HEADING = "Welcome to #{SITE_NAME}".freeze

HOME_URL = URI(SITE_URL.request_uri)

HOME_URL_SLASH = URI("#{HOME_URL.to_s.delete_suffix('/')}/")

# Full URL of the content license.
LICENSE_URL = URI('https://creativecommons.org/licenses/by-sa/4.0/')

# URL of the stylesheet.
STYLESHEET_URL = URI('/assets/css/style.css')

# URL of the MathJax configuration script.
MATHJAX_CONFIG_SCRIPT_URL = URI('/assets/js/mathjax-config.js')

# Date format for article headers.
DISPLAY_DATE_FORMAT = '%B %-d, %-Y'
