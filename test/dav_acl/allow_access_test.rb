require 'test_helper'

module Tilia
  module DavAcl
    class AllowAccessTest < Minitest::Test
      def setup
        nodes = [Dav::SimpleCollection.new('testdir')]

        @server = Dav::ServerMock.new(nodes)
        acl_plugin = Plugin.new
        acl_plugin.allow_access_to_nodes_without_acl = true
        @server.add_plugin(acl_plugin)
      end

      def test_get
        @server.http_request.method = 'GET'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_get_doesnt_exist
        @server.http_request.method = 'GET'
        @server.http_request.url = '/foo'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_head
        @server.http_request.method = 'HEAD'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_options
        @server.http_request.method = 'OPTIONS'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_put
        @server.http_request.method = 'PUT'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_acl
        @server.http_request.method = 'ACL'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_proppatch
        @server.http_request.method = 'PROPPATCH'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_copy
        @server.http_request.method = 'COPY'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_move
        @server.http_request.method = 'MOVE'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_lock
        @server.http_request.method = 'LOCK'
        @server.http_request.url = '/testdir'

        assert(@server.emit('beforeMethod', [@server.http_request, @server.http_response]))
      end

      def test_before_bind
        assert(@server.emit('beforeBind', ['testdir/file']))
      end

      def test_before_unbind
        assert(@server.emit('beforeUnbind', ['testdir']))
      end
    end
  end
end
