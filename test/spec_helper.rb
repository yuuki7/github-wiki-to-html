# frozen_string_literal: true

# Make `bundle exec rspec` self-sufficient: put ./lib on the load path even
# without `rake test`'s implicit environment.
lib_dir = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'wikinder/github/wiki'
require_relative 'support/fixture_wiki'
