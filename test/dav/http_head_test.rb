require 'test_helper'

module Tilia
  module Dav
    # Tests related to the HEAD request.
    class HttpHeadTest < DavServerTest
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

      def test_head
        request = Http::Request.new('HEAD', '//file1')
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

        assert_equal('', response.body_as_string)
      end

      # According to the specs, HEAD should behave identical to GET. But, broken
      # clients needs HEAD requests on collections to respond with a 200, so
      # that's what we do.
      def test_head_collection
        request = Http::Request.new('HEAD', '/dir')
        response = self.request(request)

        assert_equal(200, response.status)
      end

      # HEAD automatically internally maps to GET via a sub-request.
      # The Auth plugin must not be triggered twice for these, so we'll
      # test for that.
      def test_double_auth
        count = 0

        auth_backend = Auth::Backend::BasicCallBack.new(
          lambda do |_user_name, _password|
            count += 1
            true
          end
        )
        @server.add_plugin(
          Auth::Plugin.new(
            auth_backend
          )
        )
        request = Http::Request.new(
          'HEAD',
          '/file1',
          'Authorization' => "Basic #{Base64.strict_encode64('user:pass')}"
        )
        response = self.request(request)

        assert_equal(200, response.status)
        assert_equal(1, count, 'Auth was triggered twice :(')
      end
    end
  end
end
