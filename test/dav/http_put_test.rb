require 'test_helper'

module Tilia
  module Dav
    # Tests related to the PUT request.
    class HttpPutTest < DavServerTest
      # Sets up the DAV tree.
      #
      # @return void
      def set_up_tree
        @tree = Mock::Collection.new(
          'root',
          'file1' => 'foo'
        )
      end

      # A successful PUT of a new file.
      def test_put
        request = Http::Request.new('PUT', '/file2', {}, 'hello')

        response = self.request(request)

        assert_equal(201, response.status, "Incorrect status code received. Full response body: #{response.body_as_string}")

        assert_equal(
          'hello',
          @server.tree.node_for_path('file2').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('hello')}\""]
          },
          response.headers
        )
      end

      # A successful PUT on an existing file.
      def test_put_existing
        request = Http::Request.new('PUT', '/file1', {}, 'bar')

        response = self.request(request)

        assert_equal(204, response.status)

        assert_equal(
          'bar',
          @server.tree.node_for_path('file1').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('bar')}\""]
          },
          response.headers
        )
      end

      # PUT on existing file with If-Match: *
      def test_put_existing_if_match_star
        request = Http::Request.new(
          'PUT',
          '/file1',
          { 'If-Match' => '*' },
          'hello'
        )

        response = self.request(request)

        assert_equal(204, response.status)

        assert_equal(
          'hello',
          @server.tree.node_for_path('file1').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('hello')}\""]
          },
          response.headers
        )
      end

      # PUT on existing file with If-Match: with a correct etag
      def test_put_existing_if_match_correct
        request = Http::Request.new(
          'PUT',
          '/file1',
          { 'If-Match' => "\"#{Digest::MD5.hexdigest('foo')}\"" },
          'hello'
        )

        response = self.request(request)

        assert_equal(204, response.status)

        assert_equal(
          'hello',
          @server.tree.node_for_path('file1').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('hello')}\""]
          },
          response.headers
        )
      end

      # PUT with Content-Range should be rejected.
      def test_put_content_range
        request = Http::Request.new(
          'PUT',
          '/file2',
          { 'Content-Range' => 'bytes/100-200' },
          'hello'
        )

        response = self.request(request)
        assert_equal(400, response.status)
      end

      # PUT on non-existing file with If-None-Match: * should work.
      def test_put_if_none_match_star
        request = Http::Request.new(
          'PUT',
          '/file2',
          { 'If-None-Match' => '*' },
          'hello'
        )

        response = self.request(request)

        assert_equal(201, response.status)

        assert_equal(
          'hello',
          @server.tree.node_for_path('file2').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('hello')}\""]
          },
          response.headers
        )
      end

      # PUT on non-existing file with If-Match: * should fail.
      def test_put_if_match_star
        request = Http::Request.new(
          'PUT',
          '/file2',
          { 'If-Match' => '*' },
          'hello'
        )

        response = self.request(request)

        assert_equal(412, response.status)
      end

      # PUT on existing file with If-None-Match: * should fail.
      def test_put_existing_if_none_match_star
        request = Http::Request.new(
          'PUT',
          '/file1',
          { 'If-None-Match' => '*' },
          'hello'
        )
        request.body = 'hello'

        response = self.request(request)

        assert_equal(412, response.status)
      end

      # PUT thats created in a non-collection should be rejected.
      def test_put_no_parent
        request = Http::Request.new(
          'PUT',
          '/file1/file2',
          {},
          'hello'
        )

        response = self.request(request)
        assert_equal(409, response.status)
      end

      # Finder may sometimes make a request, which gets its content-body
      # stripped. We can't always prevent this from happening, but in some cases
      # we can detected this and return an error instead.
      def test_finder_put_success
        request = Http::Request.new(
          'PUT',
          '/file2',
          { 'X-Expected-Entity-Length' => '5' },
          'hello'
        )
        response = self.request(request)

        assert_equal(201, response.status)

        assert_equal(
          'hello',
          @server.tree.node_for_path('file2').get
        )

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest('hello')}\""]
          },
          response.headers
        )
      end

      # Same as the last one, but in this case we're mimicing a failed request.
      def test_finder_put_fail
        request = Http::Request.new(
          'PUT',
          '/file2',
          { 'X-Expected-Entity-Length' => '5' },
          ''
        )

        response = self.request(request)

        assert_equal(403, response.status)
      end

      # Plugins can intercept PUT. We need to make sure that works.
      def test_put_intercept
        @server.on(
          'beforeBind',
          lambda do |_uri|
            @server.http_response.status = 418
            return false
          end
        )

        request = Http::Request.new('PUT', '/file2', {}, 'hello')
        response = self.request(request)

        assert_equal(418, response.status, "Incorrect status code received. Full response body: #{response.body_as_string}")

        refute(@server.tree.node_exists('file2'))

        assert_equal(
          {
            'X-Sabre-Version' => [Version::VERSION]
          },
          response.headers
        )
      end
    end
  end
end
