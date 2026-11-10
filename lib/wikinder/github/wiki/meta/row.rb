# frozen_string_literal: true
# rbs_inline: enabled

module Wikinder
  module GitHub
    class Wiki
      class Meta
        # Represents one row of the META table.
        class Row
          attr_accessor :author #: String
          attr_accessor :creation_date #: String
          attr_accessor :modified_date #: String
          attr_accessor :language #: String
          attr_accessor :aliases #: Array[String]

          #: (meta_row) -> void
          def initialize(new_row)
            @author = new_row[:author]
            @creation_date = new_row[:creation_date]
            @modified_date = new_row[:modified_date]
            @language = new_row[:language]
            @aliases = new_row[:aliases]
          end
        end
      end
    end
  end
end
