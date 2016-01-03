module Tilia
  module Dav
    module Sync
      # This plugin all WebDAV-sync capabilities to the Server.
      #
      # WebDAV-sync is defined by rfc6578
      #
      # The sync capabilities only work with collections that implement
      # Sabre\DAV\Sync\ISyncCollection.
      class Plugin < ServerPlugin
        # Reference to server object
        #
        # @var DAV\Server
        # RUBY: attr_accessor :server

        SYNCTOKEN_PREFIX = 'http://sabre.io/ns/sync/'

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'sync'
        end

        # Initializes the plugin.
        #
        # This is when the plugin registers it's hooks.
        #
        # @param DAV\Server server
        # @return void
        def setup(server)
          @server = server
          server.xml.element_map['{DAV:}sync-collection'] = Xml::Request::SyncCollectionReport

          server.on(
            'report',
            lambda do |report_name, dom, uri|
              if report_name == '{DAV:}sync-collection'
                @server.transaction_type = 'report-sync-collection'
                sync_collection(uri, dom)
                return false
              end
            end
          )

          server.on('propFind',       method(:prop_find))
          server.on('validateTokens', method(:validate_tokens))
        end

        # Returns a list of reports this plugin supports.
        #
        # This will be used in the {DAV:}supported-report-set property.
        # Note that you still need to subscribe to the 'report' event to actually
        # implement them
        #
        # @param string uri
        # @return array
        def supported_report_set(uri)
          node = @server.tree.node_for_path(uri)
          if node.is_a?(ISyncCollection) && node.sync_token
            return ['{DAV:}sync-collection']
          end

          []
        end

        # This method handles the {DAV:}sync-collection HTTP REPORT.
        #
        # @param string uri
        # @param SyncCollectionReport report
        # @return void
        def sync_collection(uri, report)
          # Getting the data
          node = @server.tree.node_for_path(uri)
          unless node.is_a?(ISyncCollection)
            fail Exception::ReportNotSupported, 'The {DAV:}sync-collection REPORT is not supported on this url.'
          end

          token = node.sync_token
          unless token
            fail Exception::ReportNotSupported, 'No sync information is available at this node'
          end

          sync_token = report.sync_token
          if sync_token
            # Sync-token must start with our prefix
            unless sync_token[0, SYNCTOKEN_PREFIX.length] == SYNCTOKEN_PREFIX
              fail Exception::InvalidSyncToken, 'Invalid or unknown sync token'
            end

            sync_token = sync_token[SYNCTOKEN_PREFIX.length..-1]
          end

          change_info = node.changes(sync_token, report.sync_level, report.limit)

          unless change_info
            fail Exception::InvalidSyncToken, 'Invalid or unknown sync token'
          end

          # Encoding the response
          send_sync_collection_response(
            change_info['syncToken'],
            uri,
            change_info['added'],
            change_info['modified'],
            change_info['deleted'],
            report.properties
          )
        end

        protected

        # Sends the response to a sync-collection request.
        #
        # @param string sync_token
        # @param string collection_url
        # @param array added
        # @param array modified
        # @param array deleted
        # @param array properties
        # @return void
        def send_sync_collection_response(sync_token, collection_url, added, modified, deleted, properties)
          full_paths = []

          # Pre-fetching children, if this is possible.
          (added + modified).each do |item|
            full_path = collection_url + '/' + item
            full_paths << full_path
          end

          responses = []
          @server.properties_for_multiple_paths(full_paths, properties).each do |full_path, props|
            # The 'Property_Response' class is responsible for generating a
            # single {DAV:}response xml element.
            responses << Xml::Element::Response.new(full_path, props)
          end

          # Deleted items also show up as 'responses'. They have no properties,
          # and a single {DAV:}status element set as 'HTTP/1.1 404 Not Found'.
          deleted.each do |item|
            full_path = collection_url + '/' + item
            responses << Xml::Element::Response.new(full_path, {}, 404)
          end

          multi_status = Xml::Response::MultiStatus.new(responses, SYNCTOKEN_PREFIX + sync_token.to_s)

          @server.http_response.status = 207
          @server.http_response.update_header('Content-Type', 'application/xml; charset=utf-8')
          @server.http_response.body = @server.xml.write('{DAV:}multistatus', multi_status, @server.base_uri)
        end

        public

        # This method is triggered whenever properties are requested for a node.
        # We intercept this to see if we must return a {DAV:}sync-token.
        #
        # @param DAV\PropFind prop_find
        # @param DAV\INode node
        # @return void
        def prop_find(prop_find, node)
          prop_find.handle(
            '{DAV:}sync-token',
            lambda do
              if !node.is_a?(ISyncCollection)
                return nil
              else
                token = node.sync_token
                return nil unless token
              end
              return SYNCTOKEN_PREFIX + token.to_s
            end
          )
        end

        # The validateTokens event is triggered before every request.
        #
        # It's a moment where this plugin can check all the supplied lock tokens
        # in the If: header, and check if they are valid.
        #
        # @param RequestInterface request
        # @param array conditions
        # @return void
        def validate_tokens(_request, conditions_box)
          conditions = conditions_box.value
          conditions.each_with_index do |condition, kk|
            condition['tokens'].each_with_index do |token, ii|
              # Sync-tokens must always start with our designated prefix.
              if token['token'][0, SYNCTOKEN_PREFIX.length] != SYNCTOKEN_PREFIX
                next
              end

              # Checking if the token is a match.
              node = @server.tree.node_for_path(condition['uri'])

              if node.is_a?(ISyncCollection) && node.sync_token.to_s == token['token'][SYNCTOKEN_PREFIX.length..-1]
                conditions[kk]['tokens'][ii]['validToken'] = true
              end
            end
          end
          conditions_box.value = conditions
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
            'description' => 'Adds support for WebDAV Collection Sync (rfc6578)',
            'link'        => 'http://sabre.io/dav/sync/'
          }
        end
      end
    end
  end
end
