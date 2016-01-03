module Tilia
  module Dav
    class Exception
      # TooManyMatches
      #
      # This exception is emited for the {DAV:}number-of-matches-within-limits
      # post-condition, as defined in rfc6578, section 3.2.
      class TooManyMatches < Forbidden
        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:number-of-matches-within-limits')
          error_node << error
        end
      end
    end
  end
end
