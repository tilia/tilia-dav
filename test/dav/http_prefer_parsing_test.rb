require 'test_helper'

module Tilia
  module Dav
    class HttpPreferParsingTest < DavServerTest
      def test_parse_simple
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_PREFER' => 'return-asynch'
        )

        server = ServerMock.new
        server.http_request = http_request

        assert_equal(
          {
            'respond-async' => true,
            'return'        => nil,
            'handling'      => false,
            'wait'          => nil
          },
          server.http_prefer
        )
      end

      def test_parse_value
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_PREFER' => 'wait=10'
        )

        server = ServerMock.new
        server.http_request = http_request

        assert_equal(
          {
            'respond-async' => false,
            'return'        => nil,
            'handling'      => false,
            'wait'          => '10'
          },
          server.http_prefer
        )
      end

      def test_parse_multiple
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_PREFER' => 'return-minimal, strict,lenient'
        )

        server = ServerMock.new
        server.http_request = http_request

        assert_equal(
          {
            'respond-async' => false,
            'return'        => 'minimal',
            'handling'      => 'lenient',
            'wait'          => nil
          },
          server.http_prefer
        )
      end

      def test_parse_weird_value
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_PREFER' => 'BOOOH'
        )

        server = ServerMock.new
        server.http_request = http_request

        assert_equal(
          {
            'respond-async' => false,
            'return'        => nil,
            'handling'      => false,
            'wait'          => nil,
            'boooh'         => true
          },
          server.http_prefer
        )
      end

      def test_brief
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_BRIEF' => 't'
        )

        server = ServerMock.new
        server.http_request = http_request

        assert_equal(
          {
            'respond-async' => false,
            'return'        => 'minimal',
            'handling'      => false,
            'wait'          => nil
          },
          server.http_prefer
        )
      end

      # propfindMinimal
      #
      # @return void
      def test_propfind_minimal
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PROPFIND',
          'PATH_INFO'      => '/',
          'HTTP_PREFER'    => 'return-minimal'
        )
        request.body = <<BLA
<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
    <d:prop>
        <d:something />
        <d:resourcetype />
    </d:prop>
</d:propfind>
BLA

        response = self.request(request)

        body = response.body_as_string

        assert_equal(207, response.status, body)

        assert(body.index('resourcetype'), body)
        refute(body.index('something'), body)
      end

      def testproppatch_minimal
        request = Http::Request.new('PROPPATCH', '/', ['Prefer' => 'return-minimal'])
        request.body = <<BLA
<?xml version="1.0"?>
<d:propertyupdate xmlns:d="DAV:">
    <d:set>
        <d:prop>
            <d:something>nope!</d:something>
        </d:prop>
    </d:set>
</d:propertyupdate>
BLA

        @server.on(
          'propPatch',
          lambda do |_path, prop_patch|
            prop_patch.handle(
              '{DAV:}something',
              lambda do |_props|
                return true
              end

            )
          end
        )

        response = self.request(request)

        assert_equal(0, response.body.size, "Expected empty body: #{response.body}")
        assert_equal(204, response.status)
      end

      def testproppatch_minimal_error
        request = Http::Request.new('PROPPATCH', '/', ['Prefer' => 'return-minimal'])
        request.body = <<BLA
<?xml version="1.0"?>
<d:propertyupdate xmlns:d="DAV:">
    <d:set>
        <d:prop>
            <d:something>nope!</d:something>
        </d:prop>
    </d:set>
</d:propertyupdate>
BLA

        response = self.request(request)

        body = response.body_as_string

        assert_equal(207, response.status)
        assert(body.index('something'))
        assert(body.index('403 Forbidden'), body)
      end
    end
  end
end
