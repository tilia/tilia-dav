require 'test_helper'

module Tilia
  module DavAcl
    class BlockAccessTest < Minitest::Test
      def setup
        nodes = [Dav::SimpleCollection.new('testdir')]

        @server = Dav::ServerMock.new(nodes)
        @plugin = Plugin.new
        @plugin.allow_access_to_nodes_without_acl = false
        @server.add_plugin(@plugin)
      end

      def test_get
        @server.http_request.method = 'GET'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_get_doesnt_exist
        @server.http_request.method = 'GET'
        @server.http_request.url = '/foo'

        r = @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        assert(r)
      end

      def test_head
        @server.http_request.method = 'HEAD'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_options
        @server.http_request.method = 'OPTIONS'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_put
        @server.http_request.method = 'PUT'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_proppatch
        @server.http_request.method = 'PROPPATCH'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_copy
        @server.http_request.method = 'COPY'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_move
        @server.http_request.method = 'MOVE'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_acl
        @server.http_request.method = 'ACL'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_lock
        @server.http_request.method = 'LOCK'
        @server.http_request.url = '/testdir'

        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeMethod', [@server.http_request, @server.http_response])
        end
      end

      def test_before_bind
        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeBind', ['testdir/file'])
        end
      end

      def test_before_unbind
        assert_raises(Exception::NeedPrivileges) do
          @server.emit('beforeUnbind', ['testdir'])
        end
      end

      def test_prop_find
        prop_find = Dav::PropFind.new(
          'testdir',
          [
            '{DAV:}displayname',
            '{DAV:}getcontentlength',
            '{DAV:}bar',
            '{DAV:}owner'
          ]
        )

        r = @server.emit('propFind', [prop_find, Dav::SimpleCollection.new('testdir')])
        assert(r)

        expected = {
          200 => {},
          404 => {},
          403 => {
            '{DAV:}displayname' => nil,
            '{DAV:}getcontentlength' => nil,
            '{DAV:}bar' => nil,
            '{DAV:}owner' => nil
          }
        }

        assert_equal(expected, prop_find.result_for_multi_status)
      end

      def test_before_get_properties_no_listing
        @plugin.hide_nodes_from_listings = true
        prop_find = Dav::PropFind.new(
          'testdir',
          [
            '{DAV:}displayname',
            '{DAV:}getcontentlength',
            '{DAV:}bar',
            '{DAV:}owner'
          ]
        )

        r = @server.emit('propFind', [prop_find, Dav::SimpleCollection.new('testdir')])
        refute(r)
      end
    end
  end
end
