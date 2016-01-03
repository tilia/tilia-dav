require 'test_helper'

module Tilia
  module Dav
    class Exception
      class PaymentRequiredTest < Minitest::Test
        def test_get_http_code
          ex = PaymentRequired.new
          assert_equal(402, ex.http_code)
        end
      end
    end
  end
end
