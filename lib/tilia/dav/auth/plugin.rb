module Tilia
  module Dav
    module Auth
      # This plugin provides Authentication for a WebDAV server.
      #
      # It works by providing a Auth\Backend class. Several examples of these
      # classes can be found in the Backend directory.
      #
      # It's possible to provide more than one backend to this plugin. If more than
      # one backend was provided, each backend will attempt to authenticate. Only if
      # all backends fail, we throw a 401.
      class Plugin < ServerPlugin
        # authentication backends
        # RUBY: attr_accessor :backends

        # The currently logged in principal. Will be `null` if nobody is currently
        # logged in.
        #
        # @var string|null
        # RUBY: attr_accessor :current_principal

        # Creates the authentication plugin
        #
        # @param Backend\BackendInterface auth_backend
        def initialize(auth_backend = nil)
          @backends = []
          add_backend(auth_backend) if auth_backend
        end

        # Adds an authentication backend to the plugin.
        #
        # @param Backend\BackendInterface auth_backend
        # @return void
        def add_backend(auth_backend)
          @backends << auth_backend
        end

        # Initializes the plugin. This function is automatically called by the server
        #
        # @param Server server
        # @return void
        def setup(server)
          server.on('beforeMethod', method(:before_method), 10)
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'auth'
        end

        # Returns the currently logged-in principal.
        #
        # This will return a string such as:
        #
        # principals/username
        # principals/users/username
        #
        # This method will return null if nobody is logged in.
        #
        # @return string|null
        attr_reader :current_principal

        # Returns the current username.
        #
        # This method is deprecated and is only kept for backwards compatibility
        # purposes. Please switch to current_principal.
        #
        # @deprecated Will be removed in a future version!
        # @return string|null
        def current_user
          # We just do a 'basename' on the principal to give back a sane value
          # here.
          user_name = Http::UrlUtil.split_path(current_principal)[1]

          user_name
        end

        # This method is called before any HTTP method and forces users to be authenticated
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def before_method(request, response)
          if @current_principal
            # We already have authentication information. This means that the
            # event has already fired earlier, and is now likely fired for a
            # sub-request.
            #
            # We don't want to authenticate users twice, so we simply don't do
            # anything here. See Issue #700 for additional reasoning.
            #
            # This is not a perfect solution, but will be fixed once the
            # "currently authenticated principal" is information that's not
            # not associated with the plugin, but rather per-request.
            #
            # See issue #580 for more information about that.
            return nil
          end

          if @backends.empty?
            fail Dav::Exception, 'No authentication backends were configured on this server.'
          end

          reasons = []
          @backends.each do |backend|
            result = backend.check(request, response)

            if !result.is_a?(Array) ||
               result.size != 2 ||
               !(result[0].is_a?(TrueClass) || result[0].is_a?(FalseClass)) ||
               !result[1].is_a?(String)
              fail Dav::Exception, 'The authentication backend did not return a correct value from the check method.'
            end

            if result[0]
              @current_principal = result[1]
              # Exit early
              return nil
            end
            reasons << result[1]
          end

          # If we got here, it means that no authentication backend was
          # successful in authenticating the user.
          @current_principal = nil

          @backends.each do |backend|
            backend.challenge(request, response)
          end
          fail Exception::NotAuthenticated, reasons.join(', ')
        end

        # Returns a bunch of meta-data about the plugin.
        #
        # Providing this information is optional, and is mainly displayed by the
        # Browser plugin.
        #
        # The description key in the returned array may contain html and will not
        # be sanitized.
        #
        # @return array
        def plugin_info
          {
            'name'        => plugin_name,
            'description' => 'Generic authentication plugin',
            'link'        => 'http://sabre.io/dav/authentication/'
          }
        end
      end
    end
  end
end
