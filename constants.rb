##
# Constants to be imported into the main script.
#
# frozen_string_literal: true

##
# Constants for the GitHub Wiki.

# Local path to the cloned wiki repository.
WIKI_REPO = Pathname('source-wiki')

# Full URL of the wiki.
WIKI_URL = URI('https://github.com/wikinder/wikinder/wiki').freeze

WIKI_URL_SLASH = ensure_trailing_slash(WIKI_URL).freeze

# Full URL of the GitHub repository where the wiki is mirrored.
MIRROR_REPO_URL = URI('https://github.com/wikinder/wikinder').freeze

MIRROR_REPO_URL_SLASH = ensure_trailing_slash(MIRROR_REPO_URL).freeze

##
# Constants for the converted site.

# Local path to the output directory.
OUTPUT_DIRECTORY = Pathname('target-site')

# Local path to the HTML template file.
HTML_TEMPLATE_FILE = Pathname('template.html.liquid')

# Title of the site.
SITE_NAME = 'Yuukinder'

ESCAPED_SITE_NAME = CGI.escape_html(SITE_NAME).freeze

# Full URL of the site.
SITE_URL = URI('https://wikinder.org').freeze

SITE_URL_SLASH = ensure_trailing_slash(SITE_URL).freeze

# Name of the publisher.
PUBLISHER_NAME = 'Wikinder'

ESCAPED_PUBLISHER_NAME = CGI.escape_html(PUBLISHER_NAME).freeze

# Full URL of the publisher.
PUBLISHER_URL = URI('https://wikinder.org').freeze

# Full URL of the publisher's logo.
PUBLISHER_LOGO_URL = SITE_URL_SLASH.merge('/assets/images/icon.jpg').freeze

# Main heading of the home page.
HOME_HEADING = "Welcome to #{SITE_NAME}".freeze

# Root-relative URL of the home page.
HOME_URL = Pathname('/wiki/')

# Full URL of the license for the content.
LICENSE_URL = URI('https://creativecommons.org/licenses/by-sa/4.0/').freeze

# Root-relative URL of the stylesheet.
STYLESHEET_URL = HOME_URL.join('assets/css/style.css')

# Root-relative URL of the MathJax configuration script.
MATHJAX_CONFIG_SCRIPT_URL = HOME_URL.join('assets/js/mathjax-config.js')

# Date format for article headers.
DISPLAY_DATE_FORMAT = '%B %-d, %-Y'
