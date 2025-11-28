##
# Constants for use in the main script.
#

##
# Constants for the GitHub Wiki.
#

# Path to the locally cloned wiki repository.
WIKI_REPO = Pathname('wikinder.wiki')

# URL of the wiki.
WIKI_URL = URI('https://github.com/wikinder/wikinder/wiki')

# Wiki URL with a trailing slash for path joining.
WIKI_URL_SLASH = URI("#{WIKI_URL.to_s.delete_suffix('/')}/")

##
# Constants for the converted site.
#

# Path to the output directory.
OUTPUT_DIRECTORY = Pathname('wikinder.github.io')

# Title of the site.
SITE_NAME = 'Wikinder'

# Heading of the home page.
HOME_HEADING = "Welcome to #{SITE_NAME}"

# URL of the site.
SITE_URL = URI('https://wikinder.org')

# Site URL with a trailing slash for path joining.
SITE_URL_SLASH = URI("#{SITE_URL.to_s.delete_suffix('/')}/")

# Base path for internal links.
BASE_PATH = Pathname(SITE_URL_SLASH.path)

# URL of the site logo.
LOGO_URL = URI.join(SITE_URL, '/assets/images/icon.jpg')

# Path to the stylesheet.
STYLESHEET_FILE = Pathname('/assets/css/style.css')

# Path to the MathJax configuration script.
MATHJAX_CONFIG_SCRIPT = Pathname('/assets/js/mathjax-config.js')

# Path to the HTML template.
HTML_TEMPLATE_FILE = Pathname('template.html.liquid')

# Format for dates displayed on articles.
DISPLAY_DATE_FORMAT = '%B %-d, %-Y'
