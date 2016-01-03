module Tilia
  module Dav
    class Exception
      # InvalidSyncToken
      #
      # This exception is emited for the {DAV:}valid-sync-token pre-condition, as
      # defined in rfc6578, section 3.2.
      #
      # http://tools.ietf.org/html/rfc6578#section-3.2
      #
      # This is emitted in cases where the the sync-token, supplied by a client is
      # either completely unknown, or has expired.
      class InvalidSyncToken < Forbidden
        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:valid-sync-token')
          error_node << error
        end
      end
    end
  end
end
