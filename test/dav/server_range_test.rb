require 'test_helper'

module Tilia
  module Dav
    class ServerRangeTest < DavServerTest
      def setup
        @setup_files = true
        super
        @server.create_file('files/test.txt', 'Test contents')
        @last_modified = Http::Util.to_http_date(
          Time.zone.at(@server.tree.node_for_path('files/test.txt').last_modified)
        )

        stream = StringIO.new
        stream.write('Test contents')
        stream.rewind
        streaming_file = Mock::StreamingFile.new(
          'no-seeking.txt',
          stream
        )
        streaming_file.size = 12
        @server.tree.node_for_path('files').add_node(streaming_file)
      end

      def test_range
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-5'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(206, response.status)
        assert_equal('st c', response.body_as_string)
      end

      def test_start_range
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [11],
            'Content-Range'   => ['bytes 2-12/13'],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(206, response.status)
        assert_equal('st contents', response.body_as_string)
      end

      def test_end_range
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=-8'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [8],
            'Content-Range'   => ['bytes 5-12/13'],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(206, response.status)
        assert_equal('contents', response.body_as_string)
      end

      def test_too_high_range
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=100-200'
        )
        response = request(request)

        assert_equal(416, response.status)
      end

      def test_crazy_range
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=8-4'
        )
        response = request(request)

        assert_equal(416, response.status)
      end

      def test_non_seekable_stream
        request = Http::Request.new(
          'GET',
          '/files/no-seeking.txt',
          'Range' => 'bytes=2-5'
        )
        response = request(request)

        assert_equal(206, response.status, response)
        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/12'],
            # 'ETag'            => ['"' . md5('Test contents') . '"'],
            'Last-Modified'   => [@last_modified]
          },
          response.headers
        )

        assert_equal('st c', response.body_as_string)
      end

      def test_if_range_etag
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-5',
          'If-Range' => '"' + Digest::MD5.hexdigest('Test contents') + '"'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(206, response.status)
        assert_equal('st c', response.body_as_string)
      end

      def test_if_range_etag_incorrect
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-5',
          'If-Range' => '"foobar"'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [13],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(200, response.status)
        assert_equal('Test contents', response.body_as_string)
      end

      def test_if_range_modification_date
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-5',
          'If-Range' => 'tomorrow'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [4],
            'Content-Range'   => ['bytes 2-5/13'],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(206, response.status)
        assert_equal('st c', response.body_as_string)
      end

      def test_if_range_modification_date_modified
        request = Http::Request.new(
          'GET',
          '/files/test.txt',
          'Range' => 'bytes=2-5',
          'If-Range' => '-2 years'
        )
        response = request(request)

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [13],
            'Last-Modified'   => [@last_modified],
            'ETag'            => ['"' + Digest::MD5.hexdigest('Test contents') + '"']
          },
          response.headers
        )

        assert_equal(200, response.status)
        assert_equal('Test contents', response.body_as_string)
      end
    end
  end
end
