module Tilia
  module CalDav
    module Exception
      # InvalidComponentType
      class InvalidComponentType < Dav::Exception::Forbidden
        # Adds in extra information in the xml response.
        #
        # This method adds the {CALDAV:}supported-calendar-component as defined in rfc4791
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('cal:supported-calendar-component')
          LibXML::XML::Namespace.new(error, 'cal', Plugin::NS_CALDAV)
          error_node << error
        end
      end
    end
  end
end
