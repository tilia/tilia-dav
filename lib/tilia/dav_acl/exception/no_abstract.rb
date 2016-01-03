module Tilia
  module DavAcl
    module Exception
      # This exception is thrown when a user tries to set a privilege that's marked
      # as abstract.
      class NoAbstract < Dav::Exception::PreconditionFailed
        # Adds in extra information in the xml response.
        #
        # This method adds the {DAV:}no-ace-conflict element as defined in rfc3744
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(_server, error_node)
          error = LibXML::XML::Node.new('d:no-abstract')
          error_node << error
        end
      end
    end
  end
end
