require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class AbstractBearerTest < Minitest::Test
          def test_check_no_headers
            request = Http::Request.new
            response = Http::Response.new

            backend = AbstractBearerMock.new

            refute(backend.check(request, response)[0])
          end

          def test_check_invalid_token
            request = Http::Sapi.create_from_server_array(
              'HTTP_AUTHORIZATION' => 'Bearer foo'
            )
            response = Http::Response.new

            backend = AbstractBearerMock.new

            refute(backend.check(request, response)[0])
          end

          def test_check_success
            request = Http::Sapi.create_from_server_array(
              'HTTP_AUTHORIZATION' => 'Bearer valid',
            )
            response = Http::Response.new

            backend = AbstractBearerMock.new
            assert_equal(
              [true, 'principals/username'],
              backend.check(request, response)
            )
          end

          def test_require_auth
            request = Http::Request.new
            response = Http::Response.new

            backend = AbstractBearerMock.new
            backend.realm = 'writing unittests on a saturday night'
            backend.challenge(request, response)

            assert_equal(
              'Bearer realm="writing unittests on a saturday night"',
              response.header('WWW-Authenticate')
            )
          end
        end

        class AbstractBearerMock < AbstractBearer
          # Validates a bearer token
          #
          # This method should return true or false depending on if login
          # succeeded.
          #
          # @param string bearer_token
          # @return bool
          def validate_bearer_token(bearer_token)
            'valid' == bearer_token ? 'principals/username' : false
          end
        end
      end
    end
  end
end
