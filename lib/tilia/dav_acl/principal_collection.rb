module Tilia
  module DavAcl
    # Principals Collection
    #
    # This collection represents a list of users.
    # The users are instances of Tilia::DavAcl::Principal
    class PrincipalCollection < AbstractPrincipalCollection
      include Dav::IExtendedCollection
      include IAcl

      # This method returns a node for a principal.
      #
      # The passed array contains principal information, and is guaranteed to
      # at least contain a uri item. Other properties may or may not be
      # supplied by the authentication backend.
      #
      # @param array principal
      # @return \Sabre\DAV\INode
      def child_for_principal(principal)
        Principal.new(@principal_backend, principal)
      end

      # Creates a new collection.
      #
      # This method will receive a MkCol object with all the information about
      # the new collection that's being created.
      #
      # The MkCol object contains information about the resourceType of the new
      # collection. If you don't support the specified resourceType, you should
      # throw Exception\InvalidResourceType.
      #
      # The object also contains a list of WebDAV properties for the new
      # collection.
      #
      # You should call the handle method on this object to specify exactly
      # which properties you are storing. This allows the system to figure out
      # exactly which properties you didn't store, which in turn allows other
      # plugins (such as the propertystorage plugin) to handle storing the
      # property for you.
      #
      # @param string name
      # @param MkCol mk_col
      # @throws Exception\InvalidResourceType
      # @return void
      def create_extended_collection(name, mk_col)
        fail Dav::Exception::InvalidResourceType, 'Only resources of type {DAV:}principal may be created here' unless mk_col.has_resource_type('{DAV:}principal')

        @principal_backend.create_principal(
          "#{@principal_prefix}/#{name}",
          mk_col
        )
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        nil
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
            'principal' => '{DAV:}authenticated',
            'privilege' => '{DAV:}read',
            'protected' => true
          }
        ]
      end

      # Updates the ACL
      #
      # This method will receive a list of new ACE's as an array argument.
      #
      # @param array acl
      # @return void
      def acl=(_acl)
        fail Dav::Exception::Forbidden, 'Updating ACLs is not allowed on this node'
      end

      # Returns the list of supported privileges for this node.
      #
      # The returned data structure is a list of nested privileges.
      # See Tilia::DavAcl::Plugin::getDefaultSupportedPrivilegeSet for a simple
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
