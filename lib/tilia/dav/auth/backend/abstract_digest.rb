module Tilia
  module Dav
    module Auth
      module Backend
        # HTTP Digest authentication backend class
        #
        # This class can be used by authentication objects wishing to use HTTP Digest
        # Most of the digest logic is handled, implementors just need to worry about
        # the getDigestHash method
        class AbstractDigest
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

          # Sets the authentication realm for this backend.
          #
          # Be aware that for Digest authentication, the realm influences the digest
          # hash. Choose the realm wisely, because if you change it later, all the
          # existing hashes will break and nobody can authenticate.
          #
          # @param string realm
          # @return void
          attr_writer :realm

          # Returns a users digest hash based on the username and realm.
          #
          # If the user was not known, null must be returned.
          #
          # @param string realm
          # @param string username
          # @return string|null
          def digest_hash(_realm, _username)
          end

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
            digest = Http::Auth::Digest.new(@realm, request, response)
            digest.init

            username = digest.username

            # No username was given
            unless username
              return [false, "No 'Authorization: Digest' header found. Either the client didn't send one, or the server is misconfigured"]
            end

            hash = digest_hash(@realm, username)
            # If this was false, the user account didn't exist
            return [false, 'Username or password was incorrect'] unless hash
            unless hash.is_a?(String)
              fail Dav::Exception, 'The returned value from getDigestHash must be a string or null'
            end

            # If this was false, the password or part of the hash was incorrect.
            unless digest.validate_a1(hash)
              return [false, 'Username or password was incorrect']
            end

            [true, "#{@principal_prefix}#{username}"]
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
            auth = Http::Auth::Digest.new(@realm, request, response)
            auth.init
            auth.require_login
          end

          # TODO: document
          def initialize *args
            super
            @realm = 'tilia/dav'
            @principal_prefix = 'principals/'
          end
        end
      end
    end
  end
end
