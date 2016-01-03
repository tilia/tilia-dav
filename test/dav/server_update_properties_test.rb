require 'test_helper'

module Tilia
  module Dav
    class ServerUpdatePropertiesTest < Minitest::Test
      def setup
        tree = [Tilia::Dav::SimpleCollection.new('foo')]
        @server = Tilia::Dav::ServerMock.new(tree)
      end

      def test_update_properties_fail
        result = @server.update_properties(
          'foo',
          '{DAV:}foo' => 'bar'
        )

        expected = { '{DAV:}foo' => 403 }
        assert_equal(expected, result)
      end

      def test_update_properties_protected
        @server.on(
          'propPatch',
          lambda do |_path, prop_patch|
            prop_patch.handle_remaining(-> { true })
          end
        )
        result = @server.update_properties(
          'foo',
          '{DAV:}getetag' => 'bla',
          '{DAV:}foo' => 'bar'
        )

        expected = {
          '{DAV:}getetag' => 403,
          '{DAV:}foo' => 424
        }
        assert_equal(expected, result)
      end

      def test_update_properties_event_fail
        @server.on(
          'propPatch',
          lambda do |_path, prop_patch|
            prop_patch.update_result_code('{DAV:}foo', 404)
            prop_patch.handle_remaining(-> { true })
          end
        )

        result = @server.update_properties(
          'foo',
          '{DAV:}foo' => 'bar',
          '{DAV:}foo2' => 'bla'
        )

        expected = {
          '{DAV:}foo' => 404,
          '{DAV:}foo2' => 424
        }
        assert_equal(expected, result)
      end

      def test_update_properties_event_success
        @server.on(
          'propPatch',
          lambda do |_path, prop_patch|
            prop_patch.handle(
              ['{DAV:}foo', '{DAV:}foo2'],
              lambda do |_|
                return {
                  '{DAV:}foo' => 200,
                  '{DAV:}foo2' => 201
                }
              end
            )
          end
        )

        result = @server.update_properties(
          'foo',
          '{DAV:}foo' => 'bar',
          '{DAV:}foo2' => 'bla'
        )

        expected = {
          '{DAV:}foo' => 200,
          '{DAV:}foo2' => 201
        }
        assert_equal(expected, result)
      end
    end
  end
end
