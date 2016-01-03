require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class BasicCallBackTest < Minitest::Test
          def test_call_back
            args = []
            call_back = lambda do |user, pass|
              args = [user, pass]
              return true
            end

            backend = Auth::Backend::BasicCallBack.new(call_back)

            request = Http::Sapi.create_from_server_array(
              'HTTP_AUTHORIZATION' => "Basic #{Base64.strict_encode64('foo:bar')}"
            )
            response = Http::Response.new

            assert_equal(
              [true, 'principals/foo'],
              backend.check(request, response)
            )

            assert_equal(['foo', 'bar'], args)
          end
        end
      end
    end
  end
end
