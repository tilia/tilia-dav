module Tilia
  module Dav
    class Exception
      # LockTokenMatchesRequestUri
      #
      # This exception is thrown by UNLOCK if a supplied lock-token is invalid
      class LockTokenMatchesRequestUri < Conflict
        # Creates the exception
        def initialize(msg = 'The locktoken supplied does not match any locks on this entity')
          super
        end

        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:lock-token-matches-request-uri')
          error_node << error
        end
      end
    end
  end
end
