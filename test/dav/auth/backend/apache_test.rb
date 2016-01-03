require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class ApacheTest < Minitest::Test
          def test_construct
            backend = Auth::Backend::Apache.new
            assert_kind_of(Auth::Backend::Apache, backend)
          end

          def test_no_header
            request = Http::Request.new
            response = Http::Response.new
            backend = Auth::Backend::Apache.new

            refute(backend.check(request, response)[0])
          end

          def test_remote_user
            request = Http::Sapi.create_from_server_array(
              'REMOTE_USER' => 'username'
            )
            response = Http::Response.new
            backend = Auth::Backend::Apache.new

            assert_equal(
              [true, 'principals/username'],
              backend.check(request, response)
            )
          end

          def test_redirect_remote_user
            request = Http::Sapi.create_from_server_array(
              'REDIRECT_REMOTE_USER' => 'username'
            )
            response = Http::Response.new
            backend = Auth::Backend::Apache.new

            assert_equal(
              [true, 'principals/username'],
              backend.check(request, response)
            )
          end

          def test_require_auth
            request = Http::Request.new
            response = Http::Response.new

            backend = Auth::Backend::Apache.new
            backend.challenge(request, response)

            assert_nil(response.header('WWW-Authenticate'))
          end
        end
      end
    end
  end
end
