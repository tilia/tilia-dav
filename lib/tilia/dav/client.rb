module Tilia
  module Dav
    # SabreDAV DAV client
    #
    # This client wraps around Curl to provide a convenient API to a WebDAV
    # server.
    #
    # NOTE: This class is experimental, it's api will likely change in the future.
    class Client < Http::Client
      # The xml service.
      #
      # Uset this service to configure the property and namespace maps.
      #
      # @var mixed
      attr_accessor :xml

      # The elementMap
      #
      # This property is linked via reference to @xml.element_map.
      # It's deprecated as of version 3.0.0, and should no longer be used.
      #
      # @deprecated
      # @var array
      attr_accessor :property_map

      # Base URI
      #
      # This URI will be used to resolve relative urls.
      #
      # @var string
      # RUBY: attr_accessor :base_uri

      # Basic authentication
      AUTH_BASIC = 1

      # Digest authentication
      AUTH_DIGEST = 2

      # NTLM authentication
      AUTH_NTLM = 4

      # Identity encoding, which basically does not nothing.
      ENCODING_IDENTITY = 1

      # Deflate encoding
      ENCODING_DEFLATE = 2

      # Gzip encoding
      ENCODING_GZIP = 4

      # Sends all encoding headers.
      ENCODING_ALL = 7

      # Content-encoding
      #
      # @var int
      # RUBY: attr_accessor :encoding

      # Constructor
      #
      # Settings are provided through the 'settings' argument. The following
      # settings are supported:
      #
      #   * baseUri
      #   * userName (optional)
      #   * password (optional)
      #   * proxy (optional)
      #   * authType (optional)
      #   * encoding (optional)
      #
      #  authType must be a bitmap, using AUTH_BASIC, AUTH_DIGEST
      #  and AUTH_NTLM. If you know which authentication method will be
      #  used, it's recommended to set it, as it will save a great deal of
      #  requests to 'discover' this information.
      #
      #  Encoding is a bitmap with one of the ENCODING constants.
      #
      # @param array settings
      def initialize(settings)
        @property_map = {}
        @encoding = ENCODING_IDENTITY

        unless settings.key?('baseUri')
          fail ArgumentError, 'A baseUri must be provided'
        end

        super()

        @base_uri = settings['baseUri']

        add_curl_setting(:proxy, settings['proxy']) if settings.key?('proxy')

        if settings.key?('userName')
          user_name = settings['userName']
          password = settings['password'] || ''

          if settings.key?('authType')
            curl_type = []
            curl_type << :basic if settings['authType'] & AUTH_BASIC > 0
            curl_type << :digest if settings['authType'] & AUTH_DIGEST > 0
            curl_type << :ntlm if settings['authType'] & AUTH_NTLM > 0
          else
            curl_type = [:basic, :digest]
          end

          add_curl_setting(:httpauth, curl_type)
          add_curl_setting(:userpwd, "#{user_name}:#{password}")
        end

        if settings.key?('encoding')
          encoding = settings['encoding']

          encodings = []
          encodings << 'identity' if encoding & ENCODING_IDENTITY > 0
          encodings << 'deflate' if encoding & ENCODING_DEFLATE > 0
          encodings << 'gzip' if encoding & ENCODING_GZIP > 0

          add_curl_setting(:encoding, encodings.join(','))
        end

        @xml = Xml::Service.new
        # BC
        @property_map = @xml.element_map
      end

      # Does a PROPFIND request
      #
      # The list of requested properties must be specified as an array, in clark
      # notation.
      #
      # The returned array will contain a list of filenames as keys, and
      # properties as values.
      #
      # The properties array will contain the list of properties. Only properties
      # that are actually returned from the server (without error) will be
      # returned, anything else is discarded.
      #
      # Depth should be either 0 or 1. A depth of 1 will cause a request to be
      # made to the server to also return all child resources.
      #
      # @param string url
      # @param array properties
      # @param int depth
      # @return array
      def prop_find(url, properties, depth = 0)
        dom = LibXML::XML::Document.new

        root = LibXML::XML::Node.new('d:propfind')
        LibXML::XML::Namespace.new(root, 'd', 'DAV:')
        prop = LibXML::XML::Node.new('d:prop')

        properties.each do |property|
          (namespace, element_name) = Tilia::Xml::Service.parse_clark_notation(property)

          if namespace == 'DAV:'
            element = LibXML::XML::Node.new("d:#{element_name}")
          else
            element = LibXML::XML::Node.new("x:#{element_name}")
            LibXML::XML::Namespace.new(element, 'x', namespace)
          end

          prop << element
        end

        dom.root = root
        root << prop

        body = dom.to_s

        url = absolute_url(url)

        request = Http::Request.new(
          'PROPFIND',
          url,
          {
            'Depth'        => depth,
            'Content-Type' => 'application/xml'
          },
          body
        )

        response = send_request(request)

        fail Exception, "HTTP error: #{response.status}" if response.status.to_i >= 400

        result = parse_multi_status(response.body_as_string)

        # If depth was 0, we only return the top item
        if depth == 0
          result = result.first.second # value of first key/value pair
          return result.key?('200') ? result['200'] : {}
        end

        new_result = {}
        result.each do |href, status_list|
          new_result[href] = status_list.key?('200') ? status_list['200'] : {}
        end

        new_result
      end

      # Updates a list of properties on the server
      #
      # The list of properties must have clark-notation properties for the keys,
      # and the actual (string) value for the value. If the value is null, an
      # attempt is made to delete the property.
      #
      # @param string url
      # @param array properties
      # @return void
      def prop_patch(url, properties)
        prop_patch = Xml::Request::PropPatch.new
        prop_patch.properties = properties
        xml = @xml.write('{DAV:}propertyupdate', prop_patch)

        url = absolute_url(url)
        request = Http::Request.new(
          'PROPPATCH',
          url,
          { 'Content-Type' => 'application/xml' },
          xml
        )
        send_request(request)
      end

      # Performs an HTTP options request
      #
      # This method returns all the features from the 'DAV:' header as an array.
      # If there was no DAV header, or no contents this method will return an
      # empty array.
      #
      # @return array
      def options
        request = Http::Request.new('OPTIONS', absolute_url(''))
        response = send_request(request)

        dav = response.header('Dav')
        return [] unless dav

        features = dav.split(',')
        features.map(&:strip)
      end

      # Performs an actual HTTP request, and returns the result.
      #
      # If the specified url is relative, it will be expanded based on the base
      # url.
      #
      # The returned array contains 3 keys:
      #   * body - the response body
      #   * httpCode - a HTTP code (200, 404, etc)
      #   * headers - a list of response http headers. The header names have
      #     been lowercased.
      #
      # For large uploads, it's highly recommended to specify body as a stream
      # resource. You can easily do this by simply passing the result of
      # fopen(..., 'r').
      #
      # This method will throw an exception if an HTTP error was received. Any
      # HTTP status code above 399 is considered an error.
      #
      # Note that it is no longer recommended to use this method, use the send
      # method instead.
      #
      # @param string method
      # @param string url
      # @param string|resource|null body
      # @param array headers
      # @throws ClientException, in case a curl error occurred.
      # @return array
      def request(method, url = '', body = nil, headers = {})
        url = absolute_url(url)

        headers = {}
        response.headers.each { |k, v| headers[k.downcase] = v }

        response = send_request(Http::Request.new(method, url, headers, body))
        {
          'body'       => response.body_as_string,
          'statusCode' => response.status.to_i,
          'headers'    => headers
        }
      end

      # Returns the full url based on the given url (which may be relative). All
      # urls are expanded based on the base url as given by the server.
      #
      # @param string url
      # @return string
      def absolute_url(url)
        # If the url starts with http:// or https://, the url is already absolute.
        return url if url =~ /^http(s?):\/\//

        # If the url starts with a slash, we must calculate the url based off
        # the root of the base url.
        if url.index('/') == 0
          parts = Tilia::Uri.parse(@base_uri)
          return "#{parts['scheme']}://#{parts['host']}#{parts['port'] ? ":#{parts['port']}" : ''}#{url}"
        end

        # Otherwise...
        @base_uri + url
      end

      # Parses a WebDAV multistatus response body
      #
      # This method returns an array with the following structure
      #
      # [
      #   'url/to/resource' => [
      #     '200' => [
      #        '{DAV:}property1' => 'value1',
      #        '{DAV:}property2' => 'value2',
      #     ],
      #     '404' => [
      #        '{DAV:}property1' => null,
      #        '{DAV:}property2' => null,
      #     ],
      #   ],
      #   'url/to/resource2' => [
      #      .. etc ..
      #   ]
      # ]
      #
      #
      # @param string body xml body
      # @return array
      def parse_multi_status(body)
        multistatus = @xml.expect('{DAV:}multistatus', body)

        result = {}

        multistatus.responses.each do |response|
          result[response.href] = response.response_properties
        end

        result
      end
    end
  end
end
