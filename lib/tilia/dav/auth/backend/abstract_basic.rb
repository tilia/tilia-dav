module Tilia
  module Dav
    module Auth
      module Backend
        # HTTP Basic authentication backend class
        #
        # This class can be used by authentication objects wishing to use HTTP Basic
        # Most of the digest logic is handled, implementors just need to worry about
        # the validateUserPass method.
        class AbstractBasic
          include BackendInterface

          # Authentication Realm.
          #
          # The realm is often displayed by browser clients when showing the
          # authentication dialog.
          #
          # @var string
          # RUBY: attr_accessor :realm

          # This is the prefix that will be used to generate principal urls.
          #
          # @var string
          # RUBY: attr_accessor :principal_prefix

          protected

          # Validates a username and password
          #
          # This method should return true or false depending on if login
          # succeeded.
          #
          # @param string username
          # @param string password
          # @return bool
          def validate_user_pass(_username, _password)
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
            auth = Http::Auth::Basic.new(@realm, request, response)

            userpass = auth.credentials
            if userpass.blank?
              return [false, "No 'Authorization: Basic' header found. Either the client didn't send one, or the server is misconfigured"]
            end
            unless validate_user_pass(userpass[0], userpass[1])
              return [false, 'Username or password was incorrect']
            end
            [true, @principal_prefix + userpass[0]]
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
          def challenge(request, response)
            auth = Http::Auth::Basic.new(@realm, request, response)
            auth.require_login
          end

          # TODO: document
          def initialize
            @realm = 'sabre/dav'
            @principal_prefix = 'principals/'
          end
        end
      end
    end
  end
end
