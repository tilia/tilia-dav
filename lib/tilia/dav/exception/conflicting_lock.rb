module Tilia
  module Dav
    class Exception
      # ConflictingLock
      #
      # Similar to  the Locked exception, this exception thrown when a LOCK request
      # was made, on a resource which was already locked
      class ConflictingLock < Locked
        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          if lock
            error = LibXML::XML::Node.new('d:no-conflicting-lock')
            error_node << error

            href = LibXML::XML::Node.new('d:href', lock.uri)
            error << href
          end
        end
      end
    end
  end
end
