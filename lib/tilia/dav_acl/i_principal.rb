module Tilia
  module DavAcl
    # IPrincipal interface
    #
    # Implement this interface to define your own principals
    module IPrincipal
      include Dav::INode

      # Returns a list of alternative urls for a principal
      #
      # This can for example be an email address, or ldap url.
      #
      # @return array
      def alternate_uri_set
      end

      # Returns the full principal url
      #
      # @return string
      def principal_url
      end

      # Returns the list of group members
      #
      # If this principal is a group, this function should return
      # all member principal uri's for the group.
      #
      # @return array
      def group_member_set
      end

      # Returns the list of groups this principal is member of
      #
      # If this principal is a member of a (list of) groups, this function
      # should return a list of principal uri's for it's members.
      #
      # @return array
      def group_membership
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
      end

      # Returns the displayname
      #
      # This should be a human readable name for the principal.
      # If none is available, return the nodename.
      #
      # @return string
      def display_name
      end
    end
  end
end
