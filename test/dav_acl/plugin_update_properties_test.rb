require 'test_helper'

module Tilia
  module DavAcl
    class PluginUpdatePropertiesTest < Minitest::Test
      def test_update_properties_passthrough
        tree = [Dav::SimpleCollection.new('foo')]
        server = Dav::ServerMock.new(tree)
        server.add_plugin(Plugin.new)

        result = server.update_properties(
          'foo',
          '{DAV:}foo' => 'bar'
        )

        expected = { '{DAV:}foo' => 403 }

        assert_equal(expected, result)
      end

      def test_remove_group_members
        tree = [MockPrincipal.new('foo', 'foo')]
        server = Dav::ServerMock.new(tree)
        server.add_plugin(Plugin.new)

        result = server.update_properties(
          'foo',
          '{DAV:}group-member-set' => nil
        )

        expected = { '{DAV:}group-member-set' => 204 }

        assert_equal(expected, result)
        assert_equal([], tree[0].group_member_set)
      end

      def test_set_group_members
        tree = [MockPrincipal.new('foo', 'foo')]
        server = Dav::ServerMock.new(tree)
        server.add_plugin(Plugin.new)

        result = server.update_properties(
          'foo',
          '{DAV:}group-member-set' => Dav::Xml::Property::Href.new(['/bar', '/baz'], true)
        )

        expected = { '{DAV:}group-member-set' => 200 }

        assert_equal(expected, result)
        assert_equal(['bar', 'baz'], tree[0].group_member_set)
      end

      def test_set_bad_value
        tree = [MockPrincipal.new('foo', 'foo')]
        server = Dav::ServerMock.new(tree)
        server.add_plugin(Plugin.new)

        assert_raises(Dav::Exception) do
          server.update_properties(
            'foo',
            '{DAV:}group-member-set' => Class.new.new
          )
        end
      end

      def test_set_bad_node
        tree = [Dav::SimpleCollection.new('foo')]
        server = Dav::ServerMock.new(tree)
        server.add_plugin(Plugin.new)

        result = server.update_properties(
          'foo',
          '{DAV:}group-member-set' => Dav::Xml::Property::Href.new(['/bar', '/baz'], false)
        )

        expected = { '{DAV:}group-member-set' => 403 }

        assert_equal(expected, result)
      end
    end
  end
end
