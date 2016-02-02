require 'test_helper'

module Tilia
  module DavAcl
    class PluginAdminTest < Minitest::Test
      def setup
        principal_backend = PrincipalBackend::Mock.new

        tree = [
          MockAclNode.new('adminonly', []),
          PrincipalCollection.new(principal_backend)
        ]

        @server = Dav::ServerMock.new(tree)
        @server.sapi = Http::SapiMock.new
        plugin = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        @server.add_plugin(plugin)
      end

      def test_no_admin_access
        plugin = Plugin.new
        @server.add_plugin(plugin)

        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'OPTIONS',
          'HTTP_DEPTH'     => 1,
          'PATH_INFO'      => '/adminonly'
        )

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response
        @server.exec

        assert_equal(403, response.status)
      end

      def test_admin_access
        plugin = Plugin.new
        plugin.admin_principals = ['principals/admin']
        @server.add_plugin(plugin)

        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'OPTIONS',
          'HTTP_DEPTH'     => 1,
          'PATH_INFO'      => '/adminonly'
        )

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response
        @server.exec

        assert_equal(200, response.status)
      end
    end
  end
end
