module Tilia
  module DavAcl
    # Principal class
    #
    # This class is a representation of a simple principal
    #
    # Many WebDAV specs require a user to show up in the directory
    # structure.
    #
    # This principal also has basic ACL settings, only allowing the principal
    # access it's own principal.
    class Principal < Dav::Node
      include IPrincipal
      include Dav::IProperties
      include IAcl

      # @!attribute [rw] principal_properties
      #   @!visibility private
      #   Struct with principal information.
      #
      #   @return [Hash]

      # @!attribute [rw] principal_backend
      #   @!visibility private
      #   Principal backend
      #
      #   @return [PrincipalBackend::BackendInterface]

      # Creates the principal object
      #
      # @param IPrincipalBackend principal_backend
      # @param array principal_properties
      def initialize(principal_backend, principal_properties = {})
        fail Dav::Exception, 'The principal properties must at least contain the \'uri\' key' unless principal_properties.key?('uri')

        @principal_backend = principal_backend
        @principal_properties = principal_properties
      end

      # Returns the full principal url
      #
      # @return string
      def principal_url
        @principal_properties['uri']
      end

      # Returns a list of alternative urls for a principal
      #
      # This can for example be an email address, or ldap url.
      #
      # @return array
      def alternate_uri_set
        uris = []
        if @principal_properties.key?('{DAV:}alternate-URI-set')
          uris = @principal_properties['{DAV:}alternate-URI-set']
        end

        if @principal_properties.key?('{http://sabredav.org/ns}email-address')
          uris << "mailto:#{@principal_properties['{http://sabredav.org/ns}email-address']}"
        end

        uris.uniq
      end

      # Returns the list of group members
      #
      # If this principal is a group, this function should return
      # all member principal uri's for the group.
      #
      # @return array
      def group_member_set
        @principal_backend.group_member_set(@principal_properties['uri'])
      end

      # Returns the list of groups this principal is member of
      #
      # If this principal is a member of a (list of) groups, this function
      # should return a list of principal uri's for it's members.
      #
      # @return array
      def group_membership
        @principal_backend.group_membership(@principal_properties['uri'])
      end

      # Sets a list of group members
      #
      # If this principal is a group, this method sets all the group members.
      # The list of members is always overwritten, never appended to.
      #
      # This method should throw an exception if the members could not be set.
      #
      # @param array group_members
      # @return void
      def group_member_set=(group_members)
        @principal_backend.update_group_member_set(@principal_properties['uri'], group_members)
      end

      # Returns this principals name.
      #
      # @return string
      def name
        uri = @principal_properties['uri']
        name = Http::UrlUtil.split_path(uri)[1]
        name
      end

      # Returns the name of the user
      #
      # @return string
      def displayname
        if @principal_properties.key?('{DAV:}displayname')
          return @principal_properties['{DAV:}displayname']
        else
          return name
        end
      end

      # Returns a list of properties
      #
      # @param array requested_properties
      # @return array
      def properties(requested_properties)
        new_properties = {}
        requested_properties.each do |prop_name|
          if @principal_properties.key?(prop_name)
            new_properties[prop_name] = @principal_properties[prop_name]
          end
        end

        new_properties
      end

      # Updates properties on this node.
      #
      # This method received a PropPatch object, which contains all the
      # information about the update.
      #
      # To update specific properties, call the 'handle' method on this object.
      # Read the PropPatch documentation for more information.
      #
      # @param DAV\PropPatch prop_patch
      # @return void
      def prop_patch(prop_patch)
        @principal_backend.update_principal(
          @principal_properties['uri'],
          prop_patch
        )
      end

      # Returns the owner principal
      #
      # This must be a url to a principal, or null if there's no owner
      #
      # @return string|null
      def owner
        @principal_properties['uri']
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
            'principal' => '{DAV:}authenticated',
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
        fail Dav::Exception::MethodNotAllowed, 'Updating ACLs is not allowed here'
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
