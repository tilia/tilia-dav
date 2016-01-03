module Tilia
  module Dav
    module Auth
      module Backend
        # This is the base class for any authentication object.
        module BackendInterface
          # When this method is called, the backend must check if authentication was
          # successful.
          #
          # The returned value must be one of the following
          #
          # [true, "principals/username"]
          # [false, "reason for failure"]
          #
          # If authentication was successful, it's expected that the authentication
          # backend returns a so-called principal url.
          #
          # Examples of a principal url:
          #
          # principals/admin
          # principals/user1
          # principals/users/joe
          # principals/uid/123457
          #
          # If you don't use WebDAV ACL (RFC3744) we recommend that you simply
          # return a string such as:
          #
          # principals/users/[username]
          #
          # @param RequestInterface request
          # @param ResponseInterface response
          # @return array
          def check(_request, _response)
          end

          # This method is called when a user could not be authenticated, and
          # authentication was required for the current request.
          #
          # This gives you the opportunity to set authentication headers. The 401
          # status code will already be set.
          #
          # In this case of Basic Auth, this would for example mean that the
          # following header needs to be set:
          #
          # response.add_header('WWW-Authenticate', 'Basic realm=SabreDAV')
          #
          # Keep in mind that in the case of multiple authentication backends, other
          # WWW-Authenticate headers may already have been set, and you'll want to
          # append your own WWW-Authenticate header instead of overwriting the
          # existing one.
          #
          # @param RequestInterface request
          # @param ResponseInterface response
          # @return void
          def challenge(_request, _response)
          end
        end
      end
    end
  end
end
