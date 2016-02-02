require 'test_helper'

module Tilia
  module Dav
    class ServerRangeTest < AbstractServer
      def root_node
        FsExt::Directory.new(@temp_dir)
      end

      def test_range
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-5'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(206, @response.status)
        assert_equal('st c', @response.body_as_string[0, 4])
      end

      def test_start_range
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [11],
            'Content-Range'   => ['bytes 2-12/13'],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(206, @response.status)
        assert_equal('st contents', @response.body_as_string[0, 11])
      end

      def test_end_range
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=-8'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [8],
            'Content-Range'   => ['bytes 5-12/13'],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(206, @response.status)
        assert_equal('contents', @response.body_as_string[0, 8])
      end

      def test_too_high_range
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=100-200'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(416, @response.status)
      end

      def test_crazy_range
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=8-4'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        assert_equal(416, @response.status)
      end

      def test_if_range_etag
        node = @server.tree.node_for_path('test.txt')

        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-5',
          'HTTP_IF_RANGE'  => node.etag
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(206, @response.status)
        assert_equal('st c', @response.body_as_string[0, 4])
      end

      def test_if_range_etag_incorrect
        node = @server.tree.node_for_path('test.txt')

        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-5',
          'HTTP_IF_RANGE'  => node.etag + 'blabla'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [13],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal('Test contents', @response.body_as_string)
      end

      def test_if_range_modification_date
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-5',
          'HTTP_IF_RANGE'  => 'tomorrow'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(206, @response.status)
        assert_equal('st c', @response.body_as_string[0, 4])
      end

      def test_if_range_modification_date_modified
        server_vars = {
          'PATH_INFO'      => '/test.txt',
          'REQUEST_METHOD' => 'GET',
          'HTTP_RANGE'     => 'bytes=2-5',
          'HTTP_IF_RANGE'  => '-2 years'
        }
        filename = "#{@temp_dir}/test.txt"

        request = Http::Sapi.create_from_server_array(server_vars)
        @server.http_request = request
        @server.exec

        stat = ::File.stat(filename)
        etag = '"' + Digest::SHA1.hexdigest(stat.ino.to_s + stat.size.to_s + stat.mtime.to_s) + '"'

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [13],
            'Last-Modified'   => [Http::Util.to_http_date(::File.mtime(filename))],
            'ETag'            => [etag]
          },
          @response.headers
        )

        assert_equal(200, @response.status)
        assert_equal('Test contents', @response.body_as_string)
      end
    end
  end
end
