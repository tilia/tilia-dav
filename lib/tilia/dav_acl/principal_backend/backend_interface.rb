module Tilia
  module DavAcl
    module PrincipalBackend
      # Implement this interface to create your own principal backends.
      #
      # Creating backends for principals is entirely optional. You can also
      # implement Tilia::DavAcl::IPrincipal directly. This interface is used solely by
      # Tilia::DavAcl::AbstractPrincipalCollection.
      module BackendInterface
        # Returns a list of principals based on a prefix.
        #
        # This prefix will often contain something like 'principals'. You are only
        # expected to return principals that are in this base path.
        #
        # You are expected to return at least a 'uri' for every user, you can
        # return any additional properties if you wish so. Common properties are:
        #   {DAV:}displayname
        #   {http://sabredav.org/ns}email-address - This is a custom SabreDAV
        #     field that's actually injected in a number of other properties. If
        #     you have an email address, use this property.
        #
        # @param string prefix_path
        # @return array
        def principals_by_prefix(prefix_path)
        end

        # Returns a specific principal, specified by it's path.
        # The returned structure should be the exact same as from
        # getPrincipalsByPrefix.
        #
        # @param string path
        # @return array
        def principal_by_path(path)
        end

        # Updates one ore more webdav properties on a principal.
        #
        # The list of mutations is stored in a Sabre\DAV\PropPatch object.
        # To do the actual updates, you must tell this object which properties
        # you're going to process with the handle method.
        #
        # Calling the handle method is like telling the PropPatch object "I
        # promise I can handle updating this property".
        #
        # Read the PropPatch documenation for more info and examples.
        #
        # @param string path
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_principal(path, prop_patch)
        end

        # This method is used to search for principals matching a set of
        # properties.
        #
        # This search is specifically used by RFC3744's principal-property-search
        # REPORT.
        #
        # The actual search should be a unicode-non-case-sensitive search. The
        # keys in searchProperties are the WebDAV property names, while the values
        # are the property values to search on.
        #
        # By default, if multiple properties are submitted to this method, the
        # various properties should be combined with 'AND'. If test is set to
        # 'anyof', it should be combined using 'OR'.
        #
        # This method should simply return an array with full principal uri's.
        #
        # If somebody attempted to search on a property the backend does not
        # support, you should simply return 0 results.
        #
        # You can also just return 0 results if you choose to not support
        # searching at all, but keep in mind that this may stop certain features
        # from working.
        #
        # @param string prefix_path
        # @param array search_properties
        # @param string test
        # @return array
        def search_principals(prefix_path, search_properties, test = 'allof')
        end

        # Finds a principal by its URI.
        #
        # This method may receive any type of uri, but mailto: addresses will be
        # the most common.
        #
        # Implementation of this API is optional. It is currently used by the
        # CalDAV system to find principals based on their email addresses. If this
        # API is not implemented, some features may not work correctly.
        #
        # This method must return a relative principal path, or null, if the
        # principal was not found or you refuse to find it.
        #
        # @param string uri
        # @param string principal_prefix
        # @return string
        def find_by_uri(uri, principal_prefix)
        end

        # Returns the list of members for a group-principal
        #
        # @param string principal
        # @return array
        def group_member_set(principal)
        end

        # Returns the list of groups a principal is a member of
        #
        # @param string principal
        # @return array
        def group_membership(principal)
        end

        # Updates the list of group members for a group principal.
        #
        # The principals should be passed as a list of uri's.
        #
        # @param string principal
        # @param array members
        # @return void
        def update_group_member_set(principal, members)
        end
      end
    end
  end
end
