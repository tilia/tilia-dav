require 'test_helper'

module Tilia
  module Dav
    class PropFindTest < Minitest::Test
      def test_handle
        prop_find = PropFind.new('foo', ['{DAV:}displayname'])
        prop_find.handle('{DAV:}displayname', 'foobar')

        assert_equal(
          {
            200 => { '{DAV:}displayname' => 'foobar' },
            404 => {}
          },
          prop_find.result_for_multi_status
        )
      end

      def test_handle_call_back
        prop_find = PropFind.new('foo', ['{DAV:}displayname'])
        prop_find.handle(
          '{DAV:}displayname',
          lambda do
            return 'foobar'
          end
        )

        assert_equal(
          {
            200 => { '{DAV:}displayname' => 'foobar' },
            404 => {}
          },
          prop_find.result_for_multi_status
        )
      end

      def test_all_prop_defaults
        prop_find = PropFind.new('foo', ['{DAV:}displayname'], 0, PropFind::ALLPROPS)

        assert_equal(
          {
            200 => {}
          },
          prop_find.result_for_multi_status
        )
      end

      def test_set
        prop_find = PropFind.new('foo', ['{DAV:}displayname'])
        prop_find.set('{DAV:}displayname', 'bar')

        assert_equal(
          {
            200 => { '{DAV:}displayname' => 'bar' },
            404 => {}
          },
          prop_find.result_for_multi_status
        )
      end

      def test_set_allprop_custom
        prop_find = PropFind.new('foo', ['{DAV:}displayname'], 0, PropFind::ALLPROPS)
        prop_find.set('{DAV:}customproperty', 'bar')

        assert_equal(
          {
            200 => { '{DAV:}customproperty' => 'bar' }
          },
          prop_find.result_for_multi_status
        )
      end

      def test_set_unset
        prop_find = PropFind.new('foo', ['{DAV:}displayname'])
        prop_find.set('{DAV:}displayname', 'bar')
        prop_find.set('{DAV:}displayname', nil)

        assert_equal(
          {
            200 => {},
            404 =>  { '{DAV:}displayname' => nil }
          }, prop_find.result_for_multi_status
        )
      end
    end
  end
end
