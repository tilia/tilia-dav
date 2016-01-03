require 'test_helper'

module Tilia
  module Dav
    class ServerSimpleTest < AbstractServer
      def test_construct_array
        nodes = [Tilia::Dav::SimpleCollection.new('hello')]

        server = Tilia::Dav::ServerMock.new(nodes)
        assert_equal(nodes[0], server.tree.node_for_path('hello'))
      end

      def test_construct_incorrect_obj
        nodes = [
          Tilia::Dav::SimpleCollection.new('hello'),
          Class.new
        ]

        assert_raises(Tilia::Dav::Exception) { Tilia::Dav::ServerMock.new(nodes) }
      end

      def test_construct_invalid_arg
        assert_raises(Tilia::Dav::Exception) { Tilia::Dav::ServerMock.new(1) }
      end

      def test_options
        request = Tilia::Http::Request.new('OPTIONS', '/')
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'DAV'             => ['1, 3, extended-mkcol'],
            'MS-Author-Via'   => ['DAV'],
            'Allow'           => ['OPTIONS, GET, HEAD, DELETE, PROPFIND, PUT, PROPPATCH, COPY, MOVE, REPORT'],
            'Accept-Ranges'   => ['bytes'],
            'Content-Length'  => ['0'],
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal(nil, @response.body)
      end

      def test_options_unmapped
        request = Tilia::Http::Request.new('OPTIONS', '/unmapped')
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'DAV'             => ['1, 3, extended-mkcol'],
            'MS-Author-Via'   => ['DAV'],
            'Allow'           => ['OPTIONS, GET, HEAD, DELETE, PROPFIND, PUT, PROPPATCH, COPY, MOVE, REPORT, MKCOL'],
            'Accept-Ranges'   => ['bytes'],
            'Content-Length'  => ['0'],
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal(nil, @response.body)
      end

      def test_non_existant_method
        server_vars = {
          'REQUEST_PATH'   => '/',
          'REQUEST_METHOD' => 'BLABLA'
        }

        request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION],
            'Content-Type'    => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(501, @response.status)
      end

      def test_base_uri
        server_vars = {
          'REQUEST_PATH'   => '/blabla/test.txt',
          'REQUEST_METHOD' => 'GET'
        }
        filename = ::File.join(@temp_dir, 'test.txt')

        request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        @server.base_uri = '/blabla/'
        assert_equal('/blabla/', @server.base_uri)

        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [13],
            'Last-Modified'   => [Tilia::Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal('Test contents', @response.body_as_string)
      end

      def test_base_uri_add_slash
        tests = {
          '/'         => '/',
          '/foo'      => '/foo/',
          '/foo/'     => '/foo/',
          '/foo/bar'  => '/foo/bar/',
          '/foo/bar/' => '/foo/bar/'
        }

        tests.each do |test, result|
          @server.base_uri = test
          assert_equal(result, @server.base_uri)
        end
      end

      def test_calculate_uri
        uris = [
          'http://www.example.org/root/somepath',
          '/root/somepath',
          '/root/somepath/'
        ]

        @server.base_uri = '/root/'

        uris.each do |uri|
          assert_equal('somepath', @server.calculate_uri(uri))
        end

        @server.base_uri = '/root'

        uris.each do |uri|
          assert_equal('somepath', @server.calculate_uri(uri))
        end

        assert_equal('', @server.calculate_uri('/root'))
      end

      def test_calculate_uri_special_chars
        uris = [
          'http://www.example.org/root/%C3%A0fo%C3%B3',
          '/root/%C3%A0fo%C3%B3',
          '/root/%C3%A0fo%C3%B3/'
        ]

        @server.base_uri = '/root/'
        uris.each do |uri|
          assert_equal("\xc3\xa0fo\xc3\xb3", @server.calculate_uri(uri))
        end

        @server.base_uri = '/root'
        uris.each do |uri|
          assert_equal("\xc3\xa0fo\xc3\xb3", @server.calculate_uri(uri))
        end

        @server.base_uri = '/'
        uris.each do |uri|
          assert_equal("root/\xc3\xa0fo\xc3\xb3", @server.calculate_uri(uri))
        end
      end

      def test_calculate_uri_breakout
        uri = '/path1/'

        @server.base_uri = '/path2/'
        assert_raises(Exception::Forbidden) { @server.calculate_uri(uri) }
      end

      def test_guess_base_uri
        server_vars = {
          'REQUEST_PATH' => '/index.php/root',
          'PATH_INFO'    => '/root'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/index.php/', server.guess_base_uri)
      end

      def test_guess_base_uri_percent_encoding
        server_vars = {
          'REQUEST_PATH' => '/index.php/dir/path2/path%20with%20spaces',
          'PATH_INFO'    => '/dir/path2/path with spaces'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/index.php/', server.guess_base_uri)
      end

      # def test_guess_base_uri_percent_encoding2
      #   skip('This behaviour is not yet implemented')
      #   server_vars = {
      #     'REQUEST_PATH' => '/some%20directory+mixed/index.php/dir/path2/path%20with%20spaces',
      #     'PATH_INFO'    => '/dir/path2/path with spaces',
      #   }
      #
      #   http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
      #   server = Tilia::Dav::ServerMock.new
      #   server.http_request = http_request
      #
      #   assert_equal('/some%20directory+mixed/index.php/', server.guess_base_uri)
      # end

      def test_guess_base_uri2
        server_vars = {
          'REQUEST_PATH' => '/index.php/root/',
          'PATH_INFO'    => '/root/'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/index.php/', server.guess_base_uri)
      end

      def test_guess_base_uri_no_path_info
        server_vars = {
          'REQUEST_PATH' => '/index.php/root'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/', server.guess_base_uri)
      end

      def test_guess_base_uri_no_path_info2
        server_vars = {
          'REQUEST_PATH' => '/a/b/c/test.php'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/', server.guess_base_uri)
      end

      def test_guess_base_uri_query_string
        server_vars = {
          'REQUEST_PATH' => '/index.php/root?query_string=blabla',
          'PATH_INFO'    => '/root'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_equal('/index.php/', server.guess_base_uri)
      end

      def test_guess_base_uri_bad_config
        server_vars = {
          'REQUEST_PATH' => '/index.php/root/heyyy',
          'PATH_INFO'    => '/root'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        server = Tilia::Dav::ServerMock.new
        server.http_request = http_request

        assert_raises(Exception) { server.guess_base_uri }
      end

      def test_trigger_exception
        server_vars = {
          'REQUEST_PATH'   => '/',
          'REQUEST_METHOD' => 'FOO'
        }

        http_request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = http_request
        @server.on('beforeMethod', method(:exception_trigger))
        @server.exec

        assert_equal(
          {
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(500, @response.status)
      end

      def exception_trigger(_request, _response)
        fail Exception, 'Hola'
      end

      def test_report_not_found
        server_vars = {
          'REQUEST_PATH'   => '/',
          'REQUEST_METHOD' => 'REPORT'
        }

        request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.http_request.body = '<?xml version="1.0"?><bla:myreport xmlns:bla="http://www.rooftopsolutions.nl/NS"></bla:myreport>'
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION],
            'Content-Type'    => ['application/xml; charset=utf-8']
          },
          @response.headers
        )

        assert_equal(415, @response.status, "We got an incorrect status back. Full response body follows: #{@response.body}")
      end

      def test_report_intercepted
        server_vars = {
          'REQUEST_PATH'   => '/',
          'REQUEST_METHOD' => 'REPORT'
        }

        request = Tilia::Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.http_request.body = '<?xml version="1.0"?><bla:myreport xmlns:bla="http://www.rooftopsolutions.nl/NS"></bla:myreport>'
        @server.on('report', method(:report_handler))
        @server.exec

        assert_equal(
          {
            'X-Sabre-Version' => [Tilia::Dav::Version::VERSION],
            'testheader'      => ['testvalue']
          },
          @response.headers
        )

        assert_equal(418, @response.status, "We got an incorrect status back. Full response body follows: #{@response.body}")
      end

      def report_handler(report_name, _result, _path)
        if report_name == '{http://www.rooftopsolutions.nl/NS}myreport'
          @server.http_response.status = 418
          @server.http_response.update_header('testheader', 'testvalue')
          false
        else
          true
        end
      end

      def test_get_properties_for_children
        result = @server.properties_for_children(
          '',
          [
            '{DAV:}getcontentlength'
          ]
        )

        expected = {
          'test.txt' => { '{DAV:}getcontentlength' => 13 },
          'dir/'     => {}
        }

        assert_equal(expected, result)
      end
    end
  end
end
