module Tilia
  module Dav
    class Exception
      # MethodNotAllowed
      #
      # The 405 is thrown when a client tried to create a directory on an already
      # existing directory
      class MethodNotAllowed < Exception
        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          405
        end

        # This method allows the exception to return any extra HTTP response headers.
        #
        # The headers must be returned as an array.
        #
        # @param \Sabre\DAV\Server server
        # @return array
        def http_headers(server)
          methods = server.allowed_methods(server.request_uri)
          { 'Allow' => methods.join(', ').upcase }
        end
      end
    end
  end
end
