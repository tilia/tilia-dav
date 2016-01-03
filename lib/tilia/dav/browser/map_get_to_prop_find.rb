module Tilia
  module Dav
    module Browser
      # This is a simple plugin that will map any GET request for non-files to
      # PROPFIND allprops-requests.
      #
      # This should allow easy debugging of PROPFIND
      class MapGetToPropFind < ServerPlugin
        # reference to server class
        #
        # @var Sabre\DAV\Server
        # RUBY: attr_accessor :server

        # Initializes the plugin and subscribes to events
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server
          @server.on('method:GET', method(:http_get), 90)
        end

        # This method intercepts GET requests to non-files, and changes it into an HTTP PROPFIND request
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_get(request, response)
          node = @server.tree.node_for_path(request.path)
          return nil if node.is_a?(IFile)

          sub_request = request.clone
          sub_request.method = 'PROPFIND'

          @server.invoke_method(sub_request, response)
          false
        end
      end
    end
  end
end
