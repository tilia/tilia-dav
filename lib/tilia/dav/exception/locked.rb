module Tilia
  module Dav
    class Exception
      # Locked
      #
      # The 423 is thrown when a client tried to access a resource that was locked,
      # without supplying a valid lock token
      class Locked < Exception
        # Lock information
        #
        # @var Sabre\DAV\Locks\LockInfo
        attr_accessor :lock

        # Creates the exception
        #
        # A LockInfo object should be passed if the user should be informed
        # which lock actually has the file locked.
        #
        # @param DAV\Locks\LockInfo lock
        def initialize(lock = nil)
          self.lock = lock
        end

        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          423
        end

        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          if lock
            error = LibXML::XML::Node.new('d:lock-token-submitted')
            error_node << error

            href = LibXML::XML::Node.new('d:href', lock.uri)
            error << href
          end
        end
      end
    end
  end
end
