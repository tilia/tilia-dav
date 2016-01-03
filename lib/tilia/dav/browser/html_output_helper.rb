require 'cgi'

module Tilia
  module Dav
    module Browser
      # This class provides a few utility functions for easily generating HTML for
      # the browser plugin.
      class HtmlOutputHelper
        # Link to the root of the application.
        #
        # @var string
        # RUBY: attr_accessor :base_uri

        # List of xml namespaces.
        #
        # @var array
        # attr_accessor :namespace_map

        # Creates the object.
        #
        # baseUri must point to the root of the application. This will be used to
        # easily generate links.
        #
        # The namespaceMap contains an array with the list of xml namespaces and
        # their prefixes. WebDAV uses a lot of XML with complex namespaces, so
        # that can be used to make output a lot shorter.
        #
        # @param string base_uri
        # @param array namespace_map
        def initialize(base_uri, namespace_map)
          @base_uri = base_uri
          @namespace_map = namespace_map
        end

        # Generates a 'full' url based on a relative one.
        #
        # For relative urls, the base of the application is taken as the reference
        # url, not the 'current url of the current request'.
        #
        # Absolute urls are left alone.
        #
        # @param string path
        # @return string
        def full_url(path)
          Tilia::Uri.resolve(@base_uri, path)
        end

        # Escape string for HTML output.
        #
        # @param string input
        # @return string
        def h(input)
          CGI.escapeHTML(input)
        end

        # Generates a full <a>-tag.
        #
        # Url is automatically expanded. If label is not specified, we re-use the
        # url.
        #
        # @param string url
        # @param string label
        # @return string
        def link(url, label = nil)
          url = h(full_url(url))
          "<a href=\"#{url}\">#{label ? h(label) : url}</a>"
        end

        # This method takes an xml element in clark-notation, and turns it into a
        # shortened version with a prefix, if it was a known namespace.
        #
        # @param string element
        # @return string
        def xml_name(element)
          (ns, local_name) = Tilia::Xml::Service.parse_clark_notation(element)
          if @namespace_map.key?(ns)
            prop_name = "#{@namespace_map[ns]}:#{local_name}"
          else
            prop_name = element
          end
          "<span title=\"#{h(element)}\">#{h(prop_name)}</span>"
        end
      end
    end
  end
end
