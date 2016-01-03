require 'cgi'

module Tilia
  module Dav
    module Mount
      # This plugin provides support for RFC4709: Mounting WebDAV servers
      #
      # Simply append ?mount to any collection to generate the davmount response.
      class Plugin < ServerPlugin
        # Reference to Server class
        #
        # @var Sabre\DAV\Server
        # RUBY: attr_accessor :server

        # Initializes the plugin and registers event handles
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server
          @server.on('method:GET', method(:http_get), 90)
        end

        # 'beforeMethod' event handles. This event handles intercepts GET requests ending
        # with ?mount
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return bool
        def http_get(request, response)
          query_params = request.query_parameters
          return true unless query_params.include?('mount')

          current_uri = request.absolute_url

          # Stripping off everything after the ?
          current_uri = current_uri.split('?').first

          dav_mount(response, current_uri)

          # Returning false to break the event chain
          false
        end

        # Generates the davmount response
        #
        # @param ResponseInterface response
        # @param string uri absolute uri
        # @return void
        def dav_mount(response, uri)
          response.status = 200
          response.update_header('Content-Type', 'application/davmount+xml')
          body = "<?xml version=\"1.0\"?>\n"
          body << "<dm:mount xmlns:dm=\"http://purl.org/NET/webdav/mount\">\n"
          body << "  <dm:url>#{CGI.escapeHTML(uri)}</dm:url>\n"
          body << '</dm:mount>'
          response.body = body
        end
      end
    end
  end
end
