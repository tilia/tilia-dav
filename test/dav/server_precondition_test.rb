require 'test_helper'

module Tilia
  module Dav
    class ServerPreconditionsTest < Minitest::Test
      # @expectedException Sabre\DAV\Exception\PreconditionFailed
      def test_if_match_no_node
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/bar', 'If-Match' => '*')
        http_response = Http::Response.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_match_has_node
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-Match' => '*')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_match_wrong_etag
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-Match' => '1234')
        http_response = Http::Response.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_match_correct_etag
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-Match' => '"abc123"')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      # Evolution sometimes uses \" instead of " for If-Match headers.
      def test_if_match_evolution_etag
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-Match' => '\\"abc123\\"')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_match_multiple
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-Match' => '"hellothere", "abc123"')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_none_match_no_node
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/bar', 'If-None-Match' => '*')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_none_match_has_node
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('POST', '/foo', 'If-None-Match' => '*')
        http_response = Http::Response.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_none_match_wrong_etag
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('POST', '/foo', 'If-None-Match' => '"1234"')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_none_match_wrong_etag_multiple
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('POST', '/foo', 'If-None-Match' => '"1234", "5678"')
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_none_match_correct_etag
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('POST', '/foo', 'If-None-Match' => '"abc123"')
        http_response = Http::Response.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_none_match_correct_etag_multiple
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('POST', '/foo', 'If-None-Match' => '"1234, "abc123"')
        http_response = Http::Response.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_none_match_correct_etag_as_get
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Request.new('GET', '/foo', 'If-None-Match' => '"abc123"')
        server.http_response = Http::ResponseMock.new

        refute(server.check_preconditions(http_request, server.http_response))
        assert_equal(304, server.http_response.status)
        assert_equal({ 'ETag' => ['"abc123"'] }, server.http_response.headers)
      end

      # This was a test written for issue #515.
      def test_none_match_correct_etag_ensure_sapi_sent
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        server.sapi = Http::SapiMock.new
        Http::SapiMock.sent = 0
        http_request = Http::Request.new('GET', '/foo', 'If-None-Match' => '"abc123"')
        server.http_request = http_request
        server.http_response = Http::ResponseMock.new

        server.exec

        refute(server.check_preconditions(http_request, server.http_response))
        assert_equal(304, server.http_response.status)
        assert_equal(
          {
            'ETag' => ['"abc123"'],
            'X-Sabre-Version' => [Version::VERSION]
          },
          server.http_response.headers
        )
        assert_equal(1, Http::SapiMock.sent)
      end

      def test_if_modified_since_un_modified
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_MODIFIED_SINCE' => 'Sun, 06 Nov 1994 08:49:37 GMT',
          'PATH_INFO'     => '/foo'
        )
        server.http_response = Http::ResponseMock.new
        refute(server.check_preconditions(http_request, server.http_response))

        assert_equal(304, server.http_response.status)
        assert_equal(
          { 'Last-Modified' => ['Sat, 06 Apr 1985 23:30:00 GMT'] },
          server.http_response.headers
        )
      end

      def test_if_modified_since_modified
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_MODIFIED_SINCE' => 'Tue, 06 Nov 1984 08:49:37 GMT',
          'PATH_INFO'     => '/foo'
        )

        http_response = Http::ResponseMock.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_modified_since_invalid_date
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_MODIFIED_SINCE' => 'Your mother',
          'PATH_INFO'     => '/foo'
        )
        http_response = Http::ResponseMock.new

        # Invalid dates must be ignored, so this should return true
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_modified_since_invalid_date2
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_MODIFIED_SINCE' => 'Sun, 06 Nov 1994 08:49:37 EST',
          'PATH_INFO'     => '/foo'
        )
        http_response = Http::ResponseMock.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_unmodified_since_un_modified
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_UNMODIFIED_SINCE' => 'Sun, 06 Nov 1994 08:49:37 GMT',
          'PATH_INFO'     => '/foo'
        )
        http_response = Http::Response.new
        assert(server.check_preconditions(http_request, http_response))
      end

      def test_if_unmodified_since_modified
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_UNMODIFIED_SINCE' => 'Tue, 06 Nov 1984 08:49:37 GMT',
          'PATH_INFO'     => '/foo'
        )
        http_response = Http::ResponseMock.new
        assert_raises(Exception::PreconditionFailed) do
          server.check_preconditions(http_request, http_response)
        end
      end

      def test_if_unmodified_since_invalid_date
        root = SimpleCollection.new('root', [ServerPreconditionsNode.new])
        server = ServerMock.new(root)
        http_request = Http::Sapi.create_from_server_array(
          'HTTP_IF_UNMODIFIED_SINCE' => 'Sun, 06 Nov 1984 08:49:37 CET',
          'PATH_INFO'     => '/foo'
        )
        http_response = Http::ResponseMock.new
        assert(server.check_preconditions(http_request, http_response))
      end
    end

    class ServerPreconditionsNode < File
      def etag
        '"abc123"'
      end

      def last_modified
        # my birthday & time, I believe (Evert ^^)
        Time.zone.parse('1985-04-07 01:30 +02:00')
      end

      def name
        'foo'
      end
    end
  end
end
