module Tilia
  module Dav
    class Exception
      # ReportNotSupported
      #
      # This exception is thrown when the client requested an unknown report through
      # the REPORT method
      class ReportNotSupported < UnsupportedMediaType
        # This method allows the exception to include additional information into the WebDAV error response
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:supported-report')
          error_node << error
        end
      end
    end
  end
end
