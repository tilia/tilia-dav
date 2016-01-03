module Tilia
  module Dav
    class Exception
      # InvalidResourceType
      #
      # This exception is thrown when the user tried to create a new collection, with
      # a special resourcetype value that was not recognized by the server.
      #
      # See RFC5689 section 3.3
      class InvalidResourceType < Forbidden
        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:valid-resourcetype')
          error_node << error
        end
      end
    end
  end
end
