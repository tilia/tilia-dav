require 'test_helper'

module Tilia
  module Dav
    class ServerPluginTest < AbstractServer
      # @var Sabre\DAV\TestPlugin
      attr_accessor :plugin

      def setup
        super

        @plugin = TestPlugin.new
        @server.add_plugin(@plugin)
      end

      def test_base_class
        p = ServerPluginMock.new
        assert_equal([], p.features)
        assert_equal([], p.http_methods(''))
        assert_equal(
          {
            'name' => 'Tilia::Dav::ServerPluginMock',
            'description' => nil,
            'link' => nil
          },
          p.plugin_info
        )
      end

      def test_options
        server_vars = {
          'REQUEST_PATH'   => '/',
          'REQUEST_METHOD' => 'OPTIONS'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'DAV'             => ['1, 3, extended-mkcol, drinking'],
            'MS-Author-Via'   => ['DAV'],
            'Allow'           => ['OPTIONS, GET, HEAD, DELETE, PROPFIND, PUT, PROPPATCH, COPY, MOVE, REPORT, BEER, WINE'],
            'Accept-Ranges'   => ['bytes'],
            'Content-Length'  => ['0'],
            'X-Sabre-Version' => [Version::VERSION]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal('', @response.body_as_string)
        assert_equal('OPTIONS', @plugin.saved_before_method)
      end

      def test_get_plugin
        assert_equal(@plugin, @server.plugin(@plugin.class.to_s))
      end

      def test_unknown_plugin
        assert_nil(@server.plugin('SomeRandomClassName'))
      end

      def test_get_supported_report_set
        assert_equal([], @plugin.supported_report_set('/'))
      end

      def test_plugins
        assert_equal(
          {
            @plugin.class.to_s => @plugin,
            'core' => @server.plugin('core')
          },
          @server.plugins
        )
      end
    end

    class ServerPluginMock < ServerPlugin
      def setup(s)
      end
    end
  end
end
