module Tilia
  module CalDav
    module Subscriptions
      # This plugin adds calendar-subscription support to your CalDAV server.
      #
      # Some clients support 'managed subscriptions' server-side. This is basically
      # a list of subscription urls a user is using.
      class Plugin < Dav::ServerPlugin
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
          server.resource_type_mapping[ISubscription] = '{http://calendarserver.org/ns/}subscribed'
          server.xml.element_map['{http://calendarserver.org/ns/}source'] = Dav::Xml::Property::Href

          server.on('propFind', method(:prop_find), 150)
        end

        # This method should return a list of server-features.
        #
        # This is for example 'versioning' and is added to the DAV: header
        # in an OPTIONS response.
        #
        # @return array
        def features
          ['calendarserver-subscribed']
        end

        # Triggered after properties have been fetched.
        #
        # @param PropFind prop_find
        # @param INode node
        # @return void
        def prop_find(prop_find, _node)
          # There's a bunch of properties that must appear as a self-closing
          # xml-element. This event handler ensures that this will be the case.
          props = [
            '{http://calendarserver.org/ns/}subscribed-strip-alarms',
            '{http://calendarserver.org/ns/}subscribed-strip-attachments',
            '{http://calendarserver.org/ns/}subscribed-strip-todos'
          ]

          props.each do |prop|
            prop_find.set(prop, '', 200) if prop_find.status(prop) == 200
          end
        end

        # Returns a plugin name.
        #
        # Using this name other plugins will be able to access other plugins
        # using \Sabre\DAV\Server::getPlugin
        #
        # @return string
        def plugin_name
          'subscriptions'
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
            'description' => 'This plugin allows users to store iCalendar subscriptions in their calendar-home.',
            'link'        => nil
          }
        end
      end
    end
  end
end
