require 'test_helper'

module Tilia
  module Dav
    class ServerMKCOLTest < AbstractServer
      def test_mkcol
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = ''
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal(201, @response.status)
        assert_equal('', @response.body_as_string)
        assert(::File.exist?("#{@temp_dir}/testcol"))
      end

      def test_mkcol_unknown_body
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = 'Hello'
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(415, @response.status)
      end

      def test_mkcol_broken_xml
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = 'Hello'
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(400, @response.status, @response.body_as_string)
      end

      def test_mkcol_unknown_xml
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = '<?xml version="1.0"?><html></html>'
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(400, @response.status)
      end

      def test_mkcol_no_resource_type
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = <<XML
<?xml version="1.0"?>
<mkcol xmlns="DAV:">
  <set>
    <prop>
        <displayname>Evert</displayname>
    </prop>
  </set>
</mkcol>
XML

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(400, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_incorrect_resource_type
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = <<XML
<?xml version="1.0"?>
<mkcol xmlns="DAV:">
  <set>
    <prop>
        <resourcetype><collection /><blabla /></resourcetype>
    </prop>
  </set>
</mkcol>
XML

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(403, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_success
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = <<XML
<?xml version="1.0"?>
<mkcol xmlns="DAV:">
  <set>
    <prop>
        <resourcetype><collection /></resourcetype>
    </prop>
  </set>
</mkcol>
XML

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal(201, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_white_space_resource_type
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = <<XML
<?xml version="1.0"?>
<mkcol xmlns="DAV:">
  <set>
    <prop>
        <resourcetype>
            <collection />
        </resourcetype>
    </prop>
  </set>
</mkcol>
XML

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0']
          },
          @response.headers
        )

        assert_equal(201, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_no_parent
        server_vars = {
          'REQUEST_PATH'   => '/testnoparent/409me',
          'REQUEST_METHOD' => 'MKCOL'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = ''

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(409, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_parent_is_no_collection
        server_vars = {
          'REQUEST_PATH'   => '/test.txt/409me',
          'REQUEST_METHOD' => 'MKCOL'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = ''

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(409, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_already_exists
        server_vars = {
          'REQUEST_PATH'   => '/test.txt',
          'REQUEST_METHOD' => 'MKCOL'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = ''

        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Allow'        => ['OPTIONS, GET, HEAD, DELETE, PROPFIND, PUT, PROPPATCH, COPY, MOVE, REPORT']
          },
          @response.headers
        )

        assert_equal(405, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")
      end

      def test_mkcol_and_props
        server_vars = {
          'REQUEST_PATH'   => '/testcol',
          'REQUEST_METHOD' => 'MKCOL',
          'HTTP_CONTENT_TYPE' => 'application/xml'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = <<XML
<?xml version="1.0"?>
<mkcol xmlns="DAV:">
  <set>
    <prop>
        <resourcetype><collection /></resourcetype>
        <displayname>my new collection</displayname>
    </prop>
  </set>
</mkcol>
XML

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Wrong statuscode received. Full response body: #{@response.body_as_string}")

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )
      end
    end
  end
end
