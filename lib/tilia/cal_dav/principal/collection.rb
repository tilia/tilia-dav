module Tilia
  module CalDav
    module Principal
      # Principal collection
      #
      # This is an alternative collection to the standard ACL principal collection.
      # This collection adds support for the calendar-proxy-read and
      # calendar-proxy-write sub-principals, as defined by the caldav-proxy
      # specification.
      class Collection < DavAcl::PrincipalCollection
        # Returns a child object based on principal information
        #
        # @param array principal_info
        # @return User
        def child_for_principal(principal_info)
          User.new(@principal_backend, principal_info)
        end
      end
    end
  end
end
