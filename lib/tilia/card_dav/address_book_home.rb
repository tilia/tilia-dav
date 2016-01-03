module Tilia
  module CardDav
    # AddressBook Home class
    #
    # This collection contains a list of addressbooks associated with one user.
    class AddressBookHome < Dav::Collection
      include Dav::IExtendedCollection
      include DavAcl::IAcl

      protected

      # Principal uri
      #
      # @var array
      attr_accessor :principal_uri

      # carddavBackend
      #
      # @var Backend\BackendInterface
      attr_accessor :carddav_backend

      public

      # Constructor
      #
      # @param Backend\BackendInterface carddav_backend
      # @param string principal_uri
      def initialize(carddav_backend, principal_uri)
        @carddav_backend = carddav_backend
        @principal_uri = principal_uri
      end

      # Returns the name of this object
      #
      # @return string
      def name
        name = Uri.split(@principal_uri)[1]
        name
      end

      # Updates the name of this object
      #
      # @param string name
      # @return void
      def name=(_name)
        fail Dav::Exception::MethodNotAllowed
      end

      # Deletes this object
      #
      # @return void
      def delete
        fail Dav::Exception::MethodNotAllowed
      end

      # Returns the last modification date
      #
      # @return int
      def last_modified
        nil
      end

      # Creates a new file under this object.
      #
      # This is currently not allowed
      #
      # @param string filename
      # @param resource data
      # @return void
      def create_file(_filename, _data = nil)
        fail Dav::Exception::MethodNotAllowed, 'Creating new files in this collection is not supported'
      end

      # Creates a new directory under this object.
      #
      # This is currently not allowed.
      #
      # @param string filename
      # @return void
      def create_directory(_filename)
        fail Dav::Exception::MethodNotAllowed, 'Creating new collections in this collection is not supported'
      end

      # Returns a single addressbook, by name
      #
      # @param string name
      # @todo needs optimizing
      # @return \AddressBook
      def child(name)
        children.each do |child|
          return child if name == child.name
        end

        fail Dav::Exception::NotFound, "Addressbook with name '#{name}' could not be found"
      end

      # Returns a list of addressbooks
      #
      # @return array
      def children
        addressbooks = @carddav_backend.address_books_for_user(@principal_uri)

        objs = []
        addressbooks.each do |addressbook|
          objs << AddressBook.new(@carddav_backend, addressbook)
        end
        objs
      end

      # Creates a new address book.
      #
      # @param string name
      # @param MkCol mk_col
      # @throws DAV\Exception\InvalidResourceType
      # @return void
      def create_extended_collection(name, mk_col)
        fail Dav::Exception::InvalidResourceType, 'Unknown resourceType for this collection' unless mk_col.resource_type?("{#{Plugin::NS_CARDDAV}}addressbook")

        properties = mk_col.remaining_values
        mk_col.remaining_result_code = 201
        @carddav_backend.create_address_book(@principal_uri, name, properties)
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @principal_uri
      end

      # Returns a group principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def group
        nil
      end

      # Returns a list of ACE's for this node.
      #
      # Each ACE has the following properties:
      #   * 'privilege', a string such as {DAV:}read or {DAV:}write. These are
      #     currently the only supported privileges
      #   * 'principal', a url to the principal who owns the node
      #   * 'protected' (optional), indicating that this ACE is not allowed to
      #      be updated.
      #
      # @return array
      def acl
        [
          {
            'privilege' => '{DAV:}read',
            'principal' => @principal_uri,
            'protected' => true
          },
          {
            'privilege' => '{DAV:}write',
            'principal' => @principal_uri,
            'protected' => true
          }
        ]
      end

      # Updates the ACL
      #
      # This method will receive a list of new ACE's.
      #
      # @param array acl
      # @return void
      def acl=(_acl)
        fail Dav::Exception::MethodNotAllowed, 'Changing ACL is not yet supported'
      end

      # Returns the list of supported privileges for this node.
      #
      # The returned data structure is a list of nested privileges.
      # See Sabre\DAVACL\Plugin::getDefaultSupportedPrivilegeSet for a simple
      # standard structure.
      #
      # If null is returned from this method, the default privilege set is used,
      # which is fine for most common usecases.
      #
      # @return array|null
      def supported_privilege_set
        nil
      end
    end
  end
end
