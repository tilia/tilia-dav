module Tilia
  module Dav
    module Auth
      module Backend
        # HTTP Bearer authentication backend class
        #
        # This class can be used by authentication objects wishing to use HTTP Bearer
        # Most of the digest logic is handled, implementors just need to worry about
        # the validateBearerToken method.
        class AbstractBearer
          include BackendInterface

          protected

          # Validates a Bearer token
          #
          # This method should return the full principal url, or false if the
          # token was incorrect.
          #
          # @param string bearer_token
          # @return string|false
          def validate_bearer_token(bearer_token)
          end

          public

          # Sets the authentication realm for this backend.
          #
          # @param string realm
          # @return void
          attr_writer :realm

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
          def check(request, response)
            auth = Http::Auth::Bearer.new(
              @realm,
              request,
              response
            )

            bearer_token = auth.token
            if bearer_token.blank?
              return [false, "No 'Authorization: Bearer' header found. Either the client didn't send one, or the server is mis-configured"]
            end

            principal_url = validate_bearer_token(bearer_token)
            if principal_url.blank?
              return [false, "Bearer token was incorrect"]
            end

            return [true, principal_url]
          end

          # This method is called when a user could not be authenticated, and
          # authentication was required for the current request.
          #
          # This gives you the opportunity to set authentication headers. The 401
          # status code will already be set.
          #
          # In this case of Bearer Auth, this would for example mean that the
          # following header needs to be set:
          #
          # response.add_header('WWW-Authenticate', 'Bearer realm=SabreDAV')
          #
          # Keep in mind that in the case of multiple authentication backends, other
          # WWW-Authenticate headers may already have been set, and you'll want to
          # append your own WWW-Authenticate header instead of overwriting the
          # existing one.
          #
          # @param RequestInterface request
          # @param ResponseInterface response
          # @return void
          def challenge(request, response)
            auth = Http::Auth::Bearer.new(
              @realm,
              request,
              response
            )
            auth.require_login
          end

          # TODO: document
          def initialize *args
            @realm = 'tilia/dav'
            super
          end
        end
      end
    end
  end
end
