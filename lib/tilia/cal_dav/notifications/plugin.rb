module Tilia
  module CalDav
    module Notifications
      # Notifications plugin
      #
      # This plugin implements several features required by the caldav-notification
      # draft specification.
      #
      # Before version 2.1.0 this functionality was part of Sabre\CalDAV\Plugin but
      # this has since been split up.
      class Plugin < Dav::ServerPlugin
        # This is the namespace for the proprietary calendarserver extensions
        NS_CALENDARSERVER = 'http://calendarserver.org/ns/'

        # @!attribute [r] server
        #   @!visibility private
        #   Reference to the main server object.
        #
        #   @var Server

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'notifications'
        end

        # This initializes the plugin.
        #
        # This function is called by Sabre\DAV\Server, after
        # addPlugin is called.
        #
        # This method should set up the required event subscriptions.
        #
        # @param Server server
        # @return void
        def setup(server)
          @server = server
          @server.on('method:GET', method(:http_get), 90)
          @server.on('propFind',   method(:prop_find))

          @server.xml.namespace_map[NS_CALENDARSERVER] = 'cs'
          @server.resource_type_mapping[ICollection] = "{#{NS_CALENDARSERVER}}notification"

          @server.protected_properties += [
            "{#{NS_CALENDARSERVER}}notification-URL",
            "{#{NS_CALENDARSERVER}}notificationtype"
          ]
        end

        # PropFind
        #
        # @param PropFind prop_find
        # @param BaseINode node
        # @return void
        def prop_find(prop_find, node)
          caldav_plugin = @server.plugin('caldav')

          if node.is_a?(DavAcl::IPrincipal)
            principal_url = node.principal_url

            # notification-URL property
            prop_find.handle(
              "{#{NS_CALENDARSERVER}}notification-URL",
              lambda do
                notification_path = caldav_plugin.calendar_home_for_principal(principal_url) + '/notifications/'
                return Dav::Xml::Property::Href.new(notification_path)
              end
            )
          end

          if node.is_a?(INode)
            prop_find.handle(
              "{#{NS_CALENDARSERVER}}notificationtype",
              node.method(:notification_type)
            )
          end
        end

        # This event is triggered before the usual GET request handler.
        #
        # We use this to intercept GET calls to notification nodes, and return the
        # proper response.
        #
        # @param RequestInterface request
        # @param ResponseInterface response
        # @return void
        def http_get(request, response)
          path = request.path

          begin
            node = @server.tree.node_for_path(path)
          rescue Dav::Exception::NotFound
            return true
          end

          return true unless node.is_a?(INode)

          writer = @server.xml.writer
          writer.context_uri = @server.base_uri
          writer.open_memory
          writer.start_document
          writer.start_element('{http://calendarserver.org/ns/}notification')
          node.notification_type.xml_serialize_full(writer)
          writer.end_element

          response.update_header('Content-Type', 'application/xml')
          response.update_header('ETag', node.etag)
          response.status = 200
          response.body = writer.output_memory

          # Return false to break the event chain.
          false
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
            'description' => 'Adds support for caldav-notifications, which is required to enable caldav-sharing.',
            'link'        => 'http://sabre.io/dav/caldav-sharing/'
          }
        end
      end
    end
  end
end
