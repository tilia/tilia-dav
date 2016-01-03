module Tilia
  module DavAcl
    module Exception
      # NeedPrivileges
      #
      # The 403-need privileges is thrown when a user didn't have the appropriate
      # permissions to perform an operation
      class NeedPrivileges < Dav::Exception::Forbidden
        protected

        # The relevant uri
        #
        # @var string
        attr_accessor :uri

        # The privileges the user didn't have.
        #
        # @var array
        attr_accessor :privileges

        public

        # Constructor
        #
        # @param string uri
        # @param array privileges
        def initialize(uri, privileges)
          @uri = uri
          @privileges = privileges
        end

        # TODO: document
        def to_s
          "User did not have the required privileges (#{@privileges.join(', ')}) for path \"#{@uri}\""
        end

        # Adds in extra information in the xml response.
        #
        # This method adds the {DAV:}need-privileges element as defined in rfc3744
        #
        # @param DAV\Server server
        # @param \DOMElement error_node
        # @return void
        def serialize(server, error_node)
          error = LibXML::XML::Node.new('d:need-privileges')
          error_node << error

          @privileges.each do |privilege|
            resource = LibXML::XML::Node.new('d:resource')
            error << resource

            href = LibXML::XML::Node.new('d:href', "#{server.base_uri}#{@uri}")
            resource << href

            priv = LibXML::XML::Node.new('d:privilege')
            resource << priv

            privilege_parts = /^{([^}]*)}(.*)$/.match(privilege)
            priv << LibXML::XML::Node.new("d:#{privilege_parts[2]}")
          end
        end
      end
    end
  end
end
