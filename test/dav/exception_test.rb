require 'test_helper'

module Tilia
  module Dav
    class ExceptionTest < Minitest::Test
      def test_status
        e = Exception.new
        assert_equal(500, e.http_code)
      end

      def test_exception_statuses
        c = {
          Tilia::Dav::Exception::NotAuthenticated    => 401,
          Tilia::Dav::Exception::InsufficientStorage => 507
        }

        c.each do |klass, status|
          obj = klass.new
          assert_equal(status, obj.http_code)
        end
      end
    end
  end
end
