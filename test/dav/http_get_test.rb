require 'test_helper'

module Tilia
  module Dav
    # Tests related to the GET request.
    class HttpGetTest < DavServerTest
      # Sets up the DAV tree.
      #
      # @return void
      def set_up_tree
        @tree = Mock::Collection.new(
          'root',
          'file1' => 'foo',
          'a' => Mock::Collection.new('dir', []),
          'b' => Mock::StreamingFile.new('streaming', 'stream')
        )
      end

      def test_get
        request = Http::Request.new('GET', '/file1')
        response = self.request(request)

        assert_equal(200, response.status)

        # Removing Last-Modified because it keeps changing.
        response.remove_header('Last-Modified')

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [3],
            'ETag'            => ["\"#{Digest::MD5.hexdigest('foo')}\""]
          },
          response.headers
        )

        assert_equal('foo', response.body_as_string)
      end

      def test_get_http10
        request = Http::Request.new('GET', '/file1')
        request.http_version = '1.0'
        response = self.request(request)

        assert_equal(200, response.status)

        # Removing Last-Modified because it keeps changing.
        response.remove_header('Last-Modified')

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [3],
            'ETag'            => ["\"#{Digest::MD5.hexdigest('foo')}\""]
          },
          response.headers
        )

        assert_equal('1.0', response.http_version)
        assert_equal('foo', response.body_as_string)
      end

      def test_get404
        request = Http::Request.new('GET', '/notfound')
        response = self.request(request)

        assert_equal(404, response.status)
      end

      def test_get404_aswell
        request = Http::Request.new('GET', '/file1/subfile')
        response = self.request(request)

        assert_equal(404, response.status)
      end

      # We automatically normalize double slashes.
      def test_get_double_slash
        request = Http::Request.new('GET', '//file1')
        response = self.request(request)

        assert_equal(200, response.status)

        # Removing Last-Modified because it keeps changing.
        response.remove_header('Last-Modified')

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream'],
            'Content-Length'  => [3],
            'ETag'            => ["\"#{Digest::MD5.hexdigest('foo')}\""]
          },
          response.headers
        )

        assert_equal('foo', response.body_as_string)
      end

      def test_get_collection
        request = Http::Request.new('GET', '/dir')
        response = self.request(request)

        assert_equal(501, response.status)
      end

      def test_get_streaming
        request = Http::Request.new('GET', '/streaming')
        response = self.request(request)

        assert_equal(200, response.status)

        # Removing Last-Modified because it keeps changing.
        response.remove_header('Last-Modified')

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Type'    => ['application/octet-stream']
          },
          response.headers
        )

        assert_equal('stream', response.body_as_string)
      end
    end
  end
end
