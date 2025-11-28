##
# Constants for use in the main script.
#

##
# Constants for the GitHub Wiki
#

# Path to the locally cloned wiki repository
WIKI_REPO = Pathname('./wikinder.wiki')

# URL of the wiki
WIKI_URL = URI('https://github.com/wikinder/wikinder/wiki')

# URL with a trailing slash for joining purposes
WIKI_URL_SLASH = URI(WIKI_URL.to_s.delete_suffix('/') + '/')

##
# Constants for the converted site
#

# Path to the output directory
OUTPUT_DIRECTORY = Pathname('./wikinder.github.io')

# Title of the site
SITE_NAME = 'Wikinder'

# URL of the site
SITE_URL = URI('https://wikinder.org/')

# Base path for internal links
BASE_PATH = Pathname(SITE_URL.path)

# Path to the HTML template file
HTML_TEMPLATE_FILE = Pathname('./template.html.liquid')

# URL of the site logo
LOGO_URL = URI.join(SITE_URL, '/assets/images/icon.jpg')

# Path to the stylesheet file
STYLESHEET_FILE = Pathname('/assets/css/style.css')

# Path to the MathJax configuration script
MATHJAX_CONFIG_SCRIPT = Pathname('/assets/js/mathjax-config.js')

# Format for dates displayed on articles
DISPLAY_DATE_FORMAT = '%B %-d, %-Y'
