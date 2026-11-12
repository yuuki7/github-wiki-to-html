# frozen_string_literal: true
# rbs_inline: enabled

require 'whatlanguage'

module Wikinder
  module GitHub
    class Wiki
      # Detects the ISO language code of a page body, defaulting to English.
      module Language
        #: (String?) -> String
        def self.call(text)
          return 'en' if text.nil? || text.strip.empty?

          code = WhatLanguage.language_iso(text)
          code&.to_s || 'en'
        end
      end
    end
  end
end
