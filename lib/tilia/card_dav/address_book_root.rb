module Tilia
  module CardDav
    # AddressBook rootnode
    #
    # This object lists a collection of users, which can contain addressbooks.
    class AddressBookRoot < DavAcl::AbstractPrincipalCollection
      protected

      # Principal Backend
      #
      # @var Sabre\DAVACL\PrincipalBackend\BackendInteface
      attr_accessor :principal_backend

      # CardDAV backend
      #
      # @var Backend\BackendInterface
      attr_accessor :carddav_backend

      public

      # Constructor
      #
      # This constructor needs both a principal and a carddav backend.
      #
      # By default this class will show a list of addressbook collections for
      # principals in the 'principals' collection. If your main principals are
      # actually located in a different path, use the principal_prefix argument
      # to override this.
      #
      # @param DAVACL\PrincipalBackend\BackendInterface principal_backend
      # @param Backend\BackendInterface carddav_backend
      # @param string principal_prefix
      def initialize(principal_backend, carddav_backend, principal_prefix = 'principals')
        @carddav_backend = carddav_backend
        super(principal_backend, principal_prefix)
      end

      # Returns the name of the node
      #
      # @return string
      def name
        Plugin::ADDRESSBOOK_ROOT
      end

      # This method returns a node for a principal.
      #
      # The passed array contains principal information, and is guaranteed to
      # at least contain a uri item. Other properties may or may not be
      # supplied by the authentication backend.
      #
      # @param array principal
      # @return \Sabre\DAV\INode
      def child_for_principal(principal)
        AddressBookHome.new(@carddav_backend, principal['uri'])
      end
    end
  end
end
