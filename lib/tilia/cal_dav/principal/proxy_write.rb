module Tilia
  module CalDav
    module Principal
      # ProxyWrite principal
      #
      # This class represents a principal group, hosted under the main principal.
      # This is needed to implement 'Calendar delegation' support. This class is
      # instantiated by User.
      class ProxyWrite
        include IProxyWrite

        # @!attribute [r] principal_info
        #   @!visibility private
        #   Parent principal information
        #
        #   @var array

        # @!attribute [r] principal_backend
        #   @!visibility private
        #   Principal Backend
        #
        #   @var DAVACL\PrincipalBackend\BackendInterface

        # Creates the object
        #
        # Note that you MUST supply the parent principal information.
        #
        # @param DAVACL\PrincipalBackend\BackendInterface principal_backend
        # @param array principal_info
        def initialize(principal_backend, principal_info)
          @principal_info = principal_info
          @principal_backend = principal_backend
        end

        # Returns this principals name.
        #
        # @return string
        def name
          'calendar-proxy-write'
        end

        # Returns the last modification time
        #
        # @return null
        def last_modified
          nil
        end

        # Deletes the current node
        #
        # @throws DAV\Exception\Forbidden
        # @return void
        def delete
          fail Dav::Exception::Forbidden, 'Permission denied to delete node'
        end

        # Renames the node
        #
        # @throws DAV\Exception\Forbidden
        # @param string name The new name
        # @return void
        def name=(_name)
          fail Dav::Exception::Forbidden, 'Permission denied to rename file'
        end

        # Returns a list of alternative urls for a principal
        #
        # This can for example be an email address, or ldap url.
        #
        # @return array
        def alternate_uri_set
          []
        end

        # Returns the full principal url
        #
        # @return string
        def principal_url
          @principal_info['uri'] + '/' + name
        end

        # Returns the list of group members
        #
        # If this principal is a group, this function should return
        # all member principal uri's for the group.
        #
        # @return array
        def group_member_set
          @principal_backend.group_member_set(principal_url)
        end

        # Returns the list of groups this principal is member of
        #
        # If this principal is a member of a (list of) groups, this function
        # should return a list of principal uri's for it's members.
        #
        # @return array
        def group_membership
          @principal_backend.group_membership(principal_url)
        end

        # Sets a list of group members
        #
        # If this principal is a group, this method sets all the group members.
        # The list of members is always overwritten, never appended to.
        #
        # This method should throw an exception if the members could not be set.
        #
        # @param array principals
        # @return void
        def group_member_set=(principals)
          @principal_backend.update_group_member_set(principal_url, principals)
        end

        # Returns the displayname
        #
        # This should be a human readable name for the principal.
        # If none is available, return the nodename.
        #
        # @return string
        def display_name
          name
        end
      end
    end
  end
end
