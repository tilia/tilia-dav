module Tilia
  module Dav
    module Browser
      # WebDAV properties that implement this interface are able to generate their
      # own html output for the browser plugin.
      #
      # This is only useful for display purposes, and might make it a bit easier for
      # people to read and understand the value of some properties.
      module HtmlOutput
        # Generate html representation for this value.
        #
        # The html output is 100% trusted, and no effort is being made to sanitize
        # it. It's up to the implementor to sanitize user provided values.
        #
        # The output must be in UTF-8.
        #
        # The baseUri parameter is a url to the root of the application, and can
        # be used to construct local links.
        #
        # @param HtmlOutputHelper html
        # @return string
        def to_html(_html)
        end
      end
    end
  end
end
