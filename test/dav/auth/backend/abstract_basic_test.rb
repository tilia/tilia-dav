require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class AbstractBasicTest < Minitest::Test
          def test_check_no_headers
            request = Http::Request.new
            response = Http::Response.new

            backend = Auth::Backend::AbstractBasicMock.new

            refute(backend.check(request, response)[0])
          end

          def test_check_unknown_user
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_USER' => 'username',
              'PHP_AUTH_PW' => 'wrongpassword'
            )
            response = Http::Response.new

            backend = Auth::Backend::AbstractBasicMock.new

            refute(backend.check(request, response)[0])
          end

          def test_check_success
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_USER' => 'username',
              'PHP_AUTH_PW' => 'password'
            )
            response = Http::Response.new

            backend = Auth::Backend::AbstractBasicMock.new
            assert_equal(
              [true, 'principals/username'],
              backend.check(request, response)
            )
          end

          def test_require_auth
            request = Http::Request.new
            response = Http::Response.new

            backend = Auth::Backend::AbstractBasicMock.new
            backend.realm = 'writing unittests on a saturday night'
            backend.challenge(request, response)

            assert_equal(
              'Basic realm="writing unittests on a saturday night"',
              response.header('WWW-Authenticate')
            )
          end
        end

        class AbstractBasicMock < AbstractBasic
          # Validates a username and password
          #
          # This method should return true or false depending on if login
          # succeeded.
          #
          # @param string username
          # @param string password
          # @return bool
          def validate_user_pass(username, password)
            username == 'username' && password == 'password'
          end
        end
      end
    end
  end
end
