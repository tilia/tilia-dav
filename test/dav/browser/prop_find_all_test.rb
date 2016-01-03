require 'test_helper'

module Tilia
  module Dav
    module Browser
      class PropFindAllTest < Minitest::Test
        def test_handle_simple
          pf = PropFindAll.new('foo')
          pf.handle('{DAV:}displayname', 'foo')

          assert_equal(200, pf.status('{DAV:}displayname'))
          assert_equal('foo', pf.get('{DAV:}displayname'))
        end

        def test_handle_call_back
          pf = PropFindAll.new('foo')
          pf.handle('{DAV:}displayname', ->() { return 'foo'; })

          assert_equal(200, pf.status('{DAV:}displayname'))
          assert_equal('foo', pf.get('{DAV:}displayname'))
        end

        def test_set
          pf = PropFindAll.new('foo')
          pf.set('{DAV:}displayname', 'foo')

          assert_equal(200, pf.status('{DAV:}displayname'))
          assert_equal('foo', pf.get('{DAV:}displayname'))
        end

        def test_set_null
          pf = PropFindAll.new('foo')
          pf.set('{DAV:}displayname', nil)

          assert_equal(404, pf.status('{DAV:}displayname'))
          assert_equal(nil, pf.get('{DAV:}displayname'))
        end

        def test_get404_properties
          pf = PropFindAll.new('foo')
          pf.set('{DAV:}displayname', nil)
          assert_equal(
            ['{DAV:}displayname'],
            pf.get404_properties
          )
        end

        def test_get404_properties_nothing
          pf = PropFindAll.new('foo')
          pf.set('{DAV:}displayname', 'foo')
          assert_equal(
            ['{http://sabredav.org/ns}idk'],
            pf.get404_properties
          )
        end
      end
    end
  end
end
