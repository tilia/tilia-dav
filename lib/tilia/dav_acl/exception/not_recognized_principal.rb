module Tilia
  module DavAcl
    module Exception
      # If a client tried to set a privilege assigned to a non-existant principal,
      # this exception will be thrown.
      class NotRecognizedPrincipal < Dav::Exception::PreconditionFailed
        # Adds in extra information in the xml response.
        #
        # This method adds the {DAV:}no-ace-conflict element as defined in rfc3744
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:recognized-principal')
          error_node << error
        end
      end
    end
  end
end
