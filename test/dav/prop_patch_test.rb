require 'test_helper'

module Tilia
  module Dav
    class PropPatchTest < Minitest::Test
      def setup
        @prop_patch = PropPatch.new(
          '{DAV:}displayname' => 'foo'
        )
        assert_equal({ '{DAV:}displayname' => 'foo' }, @prop_patch.mutations)
      end

      def test_handle_single_success
        has_ran = false

        @prop_patch.handle(
          '{DAV:}displayname',
          lambda do |value|
            has_ran = true
            assert_equal('foo', value)
            return true
          end
        )

        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 200 }, result)

        assert(has_ran)
      end

      def test_handle_single_fail
        has_ran = false

        @prop_patch.handle(
          '{DAV:}displayname',
          lambda do |value|
            has_ran = true
            assert_equal('foo', value)
            return false
          end
        )

        refute(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 403 }, result)

        assert(has_ran)
      end

      def test_handle_single_custom_result
        has_ran = false

        @prop_patch.handle(
          '{DAV:}displayname',
          lambda do |value|
            has_ran = true
            assert_equal('foo', value)
            return 201
          end
        )

        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 201 }, result)

        assert(has_ran)
      end

      def test_handle_single_delete_success
        has_ran = false

        @prop_patch = PropPatch.new('{DAV:}displayname' => nil)
        @prop_patch.handle(
          '{DAV:}displayname',
          lambda do |value|
            has_ran = true
            assert_nil(value)
            return true
          end
        )

        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 204 }, result)

        assert(has_ran)
      end

      def test_handle_nothing
        has_ran = false

        @prop_patch.handle(
          '{DAV:}foobar',
          lambda do |_value|
            has_ran = true
          end
        )

        refute(has_ran)
      end

      def test_handle_remaining
        has_ran = false

        @prop_patch.handle_remaining(
          lambda do |mutations|
            has_ran = true
            assert_equal({ '{DAV:}displayname' => 'foo' }, mutations)
            return true
          end
        )

        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 200 }, result)

        assert(has_ran)
      end

      def test_handle_remaining_nothing_to_do
        has_ran = false

        @prop_patch.handle('{DAV:}displayname', ->() {})
        @prop_patch.handle_remaining(
          lambda do |_mutations|
            has_ran = true
          end
        )

        refute(has_ran)
      end

      def test_update_result_code
        @prop_patch.update_result_code('{DAV:}displayname', 201)
        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 201 }, result)
      end

      def test_update_result_code_fail
        @prop_patch.update_result_code('{DAV:}displayname', 402)
        refute(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 402 }, result)
      end

      def test_set_remaining_result_code
        @prop_patch.remaining_result_code = 204
        assert(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 204 }, result)
      end

      def test_commit_no_handler
        refute(@prop_patch.commit)
        result = @prop_patch.result
        assert_equal({ '{DAV:}displayname' => 403 }, result)
      end

      def test_handler_not_called
        has_ran = false

        @prop_patch.update_result_code('{DAV:}displayname', 402)
        @prop_patch.handle(
          '{DAV:}displayname',
          lambda do |_value|
            has_ran = true
          end
        )

        @prop_patch.commit

        # The handler is not supposed to have ran
        refute(has_ran)
      end

      def test_dependency_fail
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo',
          '{DAV:}b' => 'bar'
        )

        called_a = false
        called_b = false

        prop_patch.handle(
          '{DAV:}a',
          lambda do |_|
            called_a = true
            return false
          end
        )
        prop_patch.handle(
          '{DAV:}b',
          lambda do |_|
            called_b = true
            return false
          end
        )

        result = prop_patch.commit
        assert(called_a)
        refute(called_b)

        refute(result)

        assert_equal(
          {
            '{DAV:}a' => 403,
            '{DAV:}b' => 424
          },
          prop_patch.result
        )
      end

      # @expectedException \UnexpectedValueException
      def test_handle_single_broken_result
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo'
        )

        prop_patch.handle(
          '{DAV:}a',
          lambda do |_|
            return []
          end
        )
        assert_raises(RuntimeError) { prop_patch.commit }
      end

      def test_handle_multi_value_success
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo',
          '{DAV:}b' => 'bar',
          '{DAV:}c' => nil
        )

        called_a = false

        prop_patch.handle(
          ['{DAV:}a', '{DAV:}b', '{DAV:}c'],
          lambda do |properties|
            called_a = true
            assert_equal(
              {
                '{DAV:}a' => 'foo',
                '{DAV:}b' => 'bar',
                '{DAV:}c' => nil
              },
              properties
            )
            return true
          end
        )
        result = prop_patch.commit
        assert(called_a)
        assert(result)

        assert_equal(
          {
            '{DAV:}a' => 200,
            '{DAV:}b' => 200,
            '{DAV:}c' => 204
          },
          prop_patch.result
        )
      end

      def test_handle_multi_value_fail
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo',
          '{DAV:}b' => 'bar',
          '{DAV:}c' => nil
        )

        called_a = false

        prop_patch.handle(
          ['{DAV:}a', '{DAV:}b', '{DAV:}c'],
          lambda do |properties|
            called_a = true
            assert_equal(
              {
                '{DAV:}a' => 'foo',
                '{DAV:}b' => 'bar',
                '{DAV:}c' => nil
              },
              properties
            )
            return false
          end
        )
        result = prop_patch.commit
        assert(called_a)
        refute(result)

        assert_equal(
          {
            '{DAV:}a' => 403,
            '{DAV:}b' => 403,
            '{DAV:}c' => 403
          },
          prop_patch.result
        )
      end

      def test_handle_multi_value_custom_result
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo',
          '{DAV:}b' => 'bar',
          '{DAV:}c' => nil
        )

        called_a = false

        prop_patch.handle(
          ['{DAV:}a', '{DAV:}b', '{DAV:}c'],
          lambda do |properties|
            called_a = true
            assert_equal(
              {
                '{DAV:}a' => 'foo',
                '{DAV:}b' => 'bar',
                '{DAV:}c' => nil
              },
              properties
            )

            return {
              '{DAV:}a' => 201,
              '{DAV:}b' => 204
            }
          end
        )
        result = prop_patch.commit
        assert(called_a)
        refute(result)

        assert_equal(
          {
            '{DAV:}a' => 201,
            '{DAV:}b' => 204,
            '{DAV:}c' => 500
          },
          prop_patch.result
        )
      end

      def test_handle_multi_value_broken
        prop_patch = PropPatch.new(
          '{DAV:}a' => 'foo',
          '{DAV:}b' => 'bar',
          '{DAV:}c' => nil
        )

        prop_patch.handle(
          ['{DAV:}a', '{DAV:}b', '{DAV:}c'],
          lambda do |_properties|
            return 'hi'
          end
        )
        assert_raises(RuntimeError) { prop_patch.commit }
      end
    end
  end
end
