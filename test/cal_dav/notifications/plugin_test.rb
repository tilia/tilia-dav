require 'test_helper'

module Tilia
  module CalDav
    module Notifications
      class PluginTest < Minitest::Test
        def setup
          @caldav_backend = Backend::MockSharing.new
          principal_backend = DavAcl::PrincipalBackend::Mock.new
          calendars = CalendarRoot.new(principal_backend, @caldav_backend)
          principals = Principal::Collection.new(principal_backend)

          root = Dav::SimpleCollection.new('root')
          root.add_child(calendars)
          root.add_child(principals)

          @server = Dav::ServerMock.new(root)
          @server.sapi = Http::SapiMock.new
          @server.debug_exceptions = true
          @server.base_uri = '/'
          @plugin = Plugin.new
          @server.add_plugin(@plugin)

          # Adding ACL plugin
          @server.add_plugin(DavAcl::Plugin.new)

          # CalDAV is also required.
          @server.add_plugin(CalDav::Plugin.new)

          # Adding Auth plugin, and ensuring that we are logged in.
          auth_backend = Dav::Auth::Backend::Mock.new
          auth_plugin = Dav::Auth::Plugin.new(auth_backend)
          @server.add_plugin(auth_plugin)

          # This forces a login
          auth_plugin.before_method(Http::Request.new, Http::Response.new)

          @response = Http::ResponseMock.new
          @server.http_response = @response
        end

        def test_simple
          assert_equal([], @plugin.features)
          assert_equal('notifications', @plugin.plugin_name)
          assert_equal(
            'notifications',
            @plugin.plugin_info['name']
          )
        end

        def test_principal_properties
          http_request = Http::Request.new(
            'GET',
            '/',
            'Host' => 'sabredav.org'
          )
          @server.http_request = http_request

          props = @server.properties_for_path(
            '/principals/user1',
            ["{#{Plugin::NS_CALENDARSERVER}}notification-URL"]
          )

          assert(props[0])
          assert_has_key(200, props[0])

          assert_has_key("{#{Plugin::NS_CALENDARSERVER}}notification-URL", props[0][200])
          prop = props[0][200]["{#{Plugin::NS_CALENDARSERVER}}notification-URL"]

          assert_kind_of(Dav::Xml::Property::Href, prop)
          assert_equal('calendars/user1/notifications/', prop.href)
        end

        def test_notification_properties
          notification = Node.new(
            @caldav_backend,
            'principals/user1',
            Xml::Notification::SystemStatus.new('foo', '"1"')
          )
          prop_find = Dav::PropFind.new(
            'calendars/user1/notifications',
            ["{#{Plugin::NS_CALENDARSERVER}}notificationtype"]
          )

          @plugin.prop_find(prop_find, notification)

          assert_equal(
            notification.notification_type,
            prop_find.get("{#{Plugin::NS_CALENDARSERVER}}notificationtype")
          )
        end

        def test_notification_get
          notification = Node.new(
            @caldav_backend,
            'principals/user1',
            Xml::Notification::SystemStatus.new('foo', '"1"')
          )

          server = Dav::ServerMock.new([notification])
          caldav = Plugin.new

          server.http_request = Http::Request.new('GET', '/foo.xml')
          http_response = Http::ResponseMock.new
          server.http_response = http_response

          server.add_plugin(caldav)

          caldav.http_get(server.http_request, server.http_response)

          assert_equal(200, http_response.status)
          assert_equal(
            {
              'Content-Type' => ['application/xml'],
              'ETag'         => ['"1"']
            },
            http_response.headers
          )

          expected = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<cs:notification xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns" xmlns:cs="http://calendarserver.org/ns/">
  <cs:systemstatus type="high"/>
</cs:notification>
XML

          assert_xml_equal(expected, http_response.body_as_string)
        end

        def test_get_passthrough
          server = Dav::ServerMock.new
          caldav = Plugin.new

          http_response = Http::ResponseMock.new
          server.http_response = http_response

          server.add_plugin(caldav)

          assert(caldav.http_get(Http::Request.new('GET', '/foozz'), server.http_response))
        end
      end
    end
  end
end
