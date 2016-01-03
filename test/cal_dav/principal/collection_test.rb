require 'test_helper'

module Tilia
  module CalDav
    module Principal
      class CollectionTest < Minitest::Test
        def test_get_child_for_principal
          back = DavAcl::PrincipalBackend::Mock.new
          col = Collection.new(back)

          r = col.child_for_principal(
            'uri' => 'principals/admin'
          )
          assert_kind_of(CalDav::Principal::User, r)
        end
      end
    end
  end
end
