require 'test_helper'

module Tilia
  module CardDav
    class AddressBookRootTest < Minitest::Test
      def test_get_name
        p_backend = DavAcl::PrincipalBackend::Mock.new
        c_backend = Backend::Mock.new
        root = AddressBookRoot.new(p_backend, c_backend)
        assert_equal('addressbooks', root.name)
      end

      def test_get_child_for_principal
        p_backend = DavAcl::PrincipalBackend::Mock.new
        c_backend = Backend::Mock.new
        root = AddressBookRoot.new(p_backend, c_backend)

        children = root.children
        assert_equal(3, children.size)

        assert_kind_of(AddressBookHome, children[0])
        assert_equal('user1', children[0].name)
      end
    end
  end
end
