module Tilia
  module Dav
    class Exception
      # PreconditionFailed
      #
      # This exception is normally thrown when a client submitted a conditional request,
      # like for example an If, If-None-Match or If-Match header, which caused the HTTP
      # request to not execute (the condition of the header failed)
      class PreconditionFailed < Exception
        # When this exception is thrown, the header-name might be set.
        #
        # This allows the exception-catching code to determine which HTTP header
        # caused the exception.
        #
        # @var string
        attr_accessor :header

        # Create the exception
        #
        # @param string $message
        # @param string $header
        def initialize(header = nil)
          self.header = header
        end

        # Returns the HTTP statuscode for this exception
        #
        # @return int
        def http_code
          412
        end

        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          if header
            prop = LibXML::XML::Node.new('s:header', header)
            error_node << prop
          end
        end
      end
    end
  end
end
