module Tilia
  module CardDav
    # VCF Exporter
    #
    # This plugin adds the ability to export entire address books as .vcf files.
    # This is useful for clients that don't support CardDAV yet. They often do
    # support vcf files.
    class VcfExportPlugin < Dav::ServerPlugin
      protected

      # Reference to Server class
      #
      # @var Sabre\DAV\Server
      attr_accessor :server

      public

      # Initializes the plugin and registers event handlers
      #
      # @param DAV\Server server
      # @return void
      def setup(server)
        @server = server
        @server.on('method:GET', method(:http_get), 90)
        server.on(
          'browserButtonActions',
          lambda do |path, node, actions|
            if node.is_a?(IAddressBook)
              actions.value << "<a href=\"#{CGI.escapeHTML(path)}?export\"><span class=\"oi\" data-glyph=\"book\"></span></a>"
            end
          end
        )
      end

      # Intercepts GET requests on addressbook urls ending with ?export.
      #
      # @param RequestInterface request
      # @param ResponseInterface response
      # @return bool
      def http_get(request, response)
        query_params = request.query_parameters
        return true unless query_params.key?('export')

        path = request.path

        node = @server.tree.node_for_path(path)

        return true unless node.is_a?(IAddressBook)

        @server.transaction_type = 'get-addressbook-export'

        # Checking ACL, if available.
        acl_plugin = @server.plugin('acl')
        acl_plugin.check_privileges(path, '{DAV:}read') if acl_plugin

        response.update_header('Content-Type', 'text/directory')
        response.status = 200

        nodes = @server.properties_for_path(
          path,
          ["{#{Plugin::NS_CARDDAV}}address-data"],
          1
        )

        response.body = generate_vcf(nodes)

        # Returning false to break the event chain
        false
      end

      # Merges all vcard objects, and builds one big vcf export
      #
      # @param array nodes
      # @return string
      def generate_vcf(nodes)
        output = ''

        nodes.each do |node|
          next unless node[200].key?("{#{Plugin::NS_CARDDAV}}address-data")

          node_data = node[200]["{#{Plugin::NS_CARDDAV}}address-data"]

          # Parsing this node so VObject can clean up the output.
          vcard = VObject::Reader.read(node_data)
          output << vcard.serialize

          # Destroy circular references to PHP will GC the object.
          vcard.destroy
        end

        output
      end

      # Returns a plugin name.
      #
      # Using this name other plugins will be able to access other plugins
      # using \Sabre\DAV\Server::getPlugin
      #
      # @return string
      def plugin_name
        'vcf-export'
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
          'description' => 'Adds the ability to export CardDAV addressbooks as a single vCard file.',
          'link'        => 'http://sabre.io/dav/vcf-export-plugin/'
        }
      end
    end
  end
end
