module Tilia
  module Dav
    module Auth
      module Backend
        module AbstractSequelTest
          def test_construct
            db = sequel
            backend = Auth::Backend::Sequel.new(db)
            assert_kind_of(Auth::Backend::Sequel, backend)
          end

          def test_user_info
            db = sequel
            backend = Auth::Backend::Sequel.new(db)

            assert_nil(backend.digest_hash('realm', 'blabla'))

            expected = 'hash'
            assert_equal(expected, backend.digest_hash('realm', 'user'))
          end
        end
      end
    end
  end
end
