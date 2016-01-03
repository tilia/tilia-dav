require 'test_helper'

module Tilia
  module Dav
    class Exception
      class ServiceUnavailableTest < Minitest::Test
        def test_get_http_code
          ex = ServiceUnavailable.new
          assert_equal(503, ex.http_code)
        end
      end
    end
  end
end
