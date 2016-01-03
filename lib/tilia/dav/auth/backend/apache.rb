module Tilia
  module Dav
    module Auth
      module Backend
        # Apache authenticator
        #
        # This authentication backend assumes that authentication has been
        # configured in apache, rather than within SabreDAV.
        #
        # Make sure apache is properly configured for this to work.
        class Apache
          include BackendInterface
          # This is the prefix that will be used to generate principal urls.
          #
          # @var string
          # RUBY: attr_accessor :principal_prefix

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
          def check(request, _response)
            remote_user = request.raw_server_value('REMOTE_USER')
            unless remote_user
              remote_user = request.raw_server_value('REDIRECT_REMOTE_USER')
            end
            unless remote_user
              return [false, 'No REMOTE_USER property was found in the PHP $_SERVER super-global. This likely means your server is not configured correctly']
            end

            [true, "#{@principal_prefix}#{remote_user}"]
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

          def initialize
            @principal_prefix = 'principals/'
          end
        end
      end
    end
  end
end
