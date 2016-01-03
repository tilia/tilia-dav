module Tilia
  module DavAcl
    module Exception
      # This exception is thrown when a client attempts to set conflicting
      # permissions.
      class AceConflict < Dav::Exception::Conflict
        # Adds in extra information in the xml response.
        #
        # This method adds the {DAV:}no-ace-conflict element as defined in rfc3744
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:no-ace-conflict')
          error_node << error
        end
      end
    end
  end
end
