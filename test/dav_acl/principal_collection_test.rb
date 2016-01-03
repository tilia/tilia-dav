require 'test_helper'

module Tilia
  module DavAcl
    class PrincipalCollectionTest < Minitest::Test
      def test_basic
        backend = PrincipalBackend::Mock.new
        pc = PrincipalCollection.new(backend)
        assert_kind_of(PrincipalCollection, pc)

        assert_equal('principals', pc.name)
      end

      def test_get_children
        backend = PrincipalBackend::Mock.new
        pc = PrincipalCollection.new(backend)

        children = pc.children
        assert_kind_of(Array, children)

        children.each do |child|
          assert_kind_of(IPrincipal, child)
        end
      end

      def test_get_children_disable
        backend = PrincipalBackend::Mock.new
        pc = PrincipalCollection.new(backend)
        pc.disable_listing = true

        assert_raises(Dav::Exception::MethodNotAllowed) { pc.children }
      end

      def test_find_by_uri
        backend = PrincipalBackend::Mock.new
        pc = PrincipalCollection.new(backend)

        assert_equal('principals/user1', pc.find_by_uri('mailto:user1.sabredav@sabredav.org'))
        assert_nil(pc.find_by_uri('mailto:fake.user.sabredav@sabredav.org'))
        assert_nil(pc.find_by_uri(''))
      end
    end
  end
end
