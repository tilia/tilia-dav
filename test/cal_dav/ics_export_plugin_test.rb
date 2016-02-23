require 'test_helper'

module Tilia
  module CalDav
    class ICSExportPluginTest < Minitest::Test
      def test_init
        plugin = IcsExportPlugin.new
        server = Dav::ServerMock.new
        server.add_plugin(plugin)
        assert_equal(plugin, server.plugin('ics-export'))
        assert_equal('ics-export', plugin.plugin_info['name'])
      end

      def test_before_method
        cbackend = DatabaseUtil.backend

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1,
          '{DAV:}displayname' => 'Hello!',
          '{http://apple.com/ns/ical/}calendar-color' => '#AA0000FF'
        }
        tree = [
          Calendar.new(cbackend, props)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        refute(plugin.http_get(h, server.http_response))

        assert_equal(200, server.http_response.status)
        assert_equal(
          {
            'Content-Type' => ['text/calendar']
          },
          server.http_response.headers
        )

        obj = VObject::Reader.read(server.http_response.body)

        assert_equal(7, obj.children.size)
        assert_equal(1, obj['VERSION'].size)
        assert_equal(1, obj['CALSCALE'].size)
        assert_equal(1, obj['PRODID'].size)
        assert(obj['PRODID'].to_s.index(Dav::Version::VERSION))
        assert_equal(1, obj['VTIMEZONE'].size)
        assert_equal(1, obj['VEVENT'].size)
        assert_equal('Hello!', obj['X-WR-CALNAME'].to_s)
        assert_equal('#AA0000FF', obj['X-APPLE-CALENDAR-COLOR'].to_s)
      end

      def test_before_method_no_version
        cbackend = DatabaseUtil.backend

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)

        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        Dav::Server.expose_version = false
        refute(plugin.http_get(h, server.http_response))
        Dav::Server.expose_version = true

        assert_equal(200, server.http_response.status)
        assert_equal(
          {
            'Content-Type' => ['text/calendar']
          },
          server.http_response.headers
        )

        obj = VObject::Reader.read(server.http_response.body)

        assert_equal(5, obj.children.size)
        assert_equal(1, obj['VERSION'].size)
        assert_equal(1, obj['CALSCALE'].size)
        assert_equal(1, obj['PRODID'].size)
        refute(obj['PRODID'].to_s.index(Dav::Version::VERSION))
        assert_equal(1, obj['VTIMEZONE'].size)
        assert_equal(1, obj['VEVENT'].size)
      end

      def test_before_method_no_export
        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new
        server.add_plugin(plugin)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET'
        )
        assert(plugin.http_get(h, server.http_response))
      end

      def test_acl_integration_blocked
        cbackend = DatabaseUtil.backend

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)
        server.add_plugin(DavAcl::Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        plugin.http_get(h, server.http_response)

        # If the ACL system blocked this request, the effect will be that
        # there's no response, because the calendar information could not be
        # fetched.
        assert_nil(server.http_response.status)
      end

      def test_acl_integration_not_blocked
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)
        server.add_plugin(DavAcl::Plugin.new)
        server.add_plugin(Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new))

        # Forcing login
        server.plugin('acl').admin_principals = ['principals/admin']

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body}")
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['text/calendar']
          },
          server.http_response.headers
        )

        obj = VObject::Reader.read(server.http_response.body)

        assert_equal(5, obj.children.size)
        assert_equal(1, obj['VERSION'].size)
        assert_equal(1, obj['CALSCALE'].size)
        assert_equal(1, obj['PRODID'].size)
        assert_equal(1, obj['VTIMEZONE'].size)
        assert_equal(1, obj['VEVENT'].size)
      end

      def test_bad_start_param
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&start=foo'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(400, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body}")
      end

      def test_bad_end_param
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&end=foo'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(400, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
      end

      def test_filter_start_end
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&start=1&end=2'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        obj = VObject::Reader.read(server.http_response.body)

        assert_nil(obj['VTIMEZONE'])
        assert_nil(obj['VEVENT'])
      end

      def test_expand_no_start
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&expand=1&end=1'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(400, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
      end

      def test_expand
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&start=1&end=2000000000&expand=1'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        obj = VObject::Reader.read(server.http_response.body)

        assert_nil(obj['VTIMEZONE'])
        assert_equal(1, obj['VEVENT'].size)
      end

      def test_j_cal
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'HTTP_ACCEPT' => 'application/calendar+json',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        assert_equal('application/calendar+json', server.http_response.header('Content-Type'))
      end

      def test_j_cal_in_url
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&accept=jcal'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        assert_equal('application/calendar+json', server.http_response.header('Content-Type'))
      end

      def test_negotiate_default
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'HTTP_ACCEPT' => 'text/plain',
          'QUERY_STRING' => 'export'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        assert_equal('text/calendar', server.http_response.header('Content-Type'))
      end

      def test_filter_component_vevent
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        # add a todo to the calendar (see /tests/Sabre/TestUtil)
        cbackend.create_calendar_object(1, 'UUID-3456', DatabaseUtil.get_test_todo)

        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&componentType=VEVENT'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        obj = VObject::Reader.read(server.http_response.body)

        assert_equal(1, obj['VTIMEZONE'].size)
        assert_equal(1, obj['VEVENT'].size)
        assert_nil(obj['VTODO'])
      end

      def test_filter_component_vtodo
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        # add a todo to the calendar (see /tests/Sabre/TestUtil)
        cbackend.create_calendar_object(1, 'UUID-3456', DatabaseUtil.get_test_todo)

        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&componentType=VTODO'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(200, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
        obj = VObject::Reader.read(server.http_response.body)

        assert_nil(obj['VTIMEZONE'])
        assert_nil(obj['VEVENT'])
        assert_equal(1, obj['VTODO'].size)
      end

      def test_filter_component_bad_component
        cbackend = DatabaseUtil.backend
        pbackend = DavAcl::PrincipalBackend::Mock.new

        props = {
          'uri' => 'UUID-123467',
          'principaluri' => 'admin',
          'id' => 1
        }
        # add a todo to the calendar (see /tests/Sabre/TestUtil)
        cbackend.create_calendar_object(1, 'UUID-3456', DatabaseUtil.get_test_todo)

        tree = [
          Calendar.new(cbackend, props),
          DavAcl::PrincipalCollection.new(pbackend)
        ]

        plugin = IcsExportPlugin.new

        server = Dav::ServerMock.new(tree)
        server.sapi = Http::SapiMock.new
        server.add_plugin(plugin)
        server.add_plugin(Plugin.new)

        h = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/UUID-123467',
          'REQUEST_METHOD' => 'GET',
          'QUERY_STRING' => 'export&componentType=VVOODOO'
        )

        server.http_request = h
        server.http_response = Http::ResponseMock.new

        server.exec

        assert_equal(400, server.http_response.status, "Invalid status received. Response body: #{server.http_response.body_as_string}")
      end
    end
  end
end
