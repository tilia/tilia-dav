require 'test_helper'

module Tilia
  module Dav
    module Auth
      module Backend
        class AbstractDigestTest < Minitest::Test
          def test_check_no_headers
            request = Http::Request.new
            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            refute(backend.check(request, response)[0])
          end

          def test_check_bad_get_user_info_response
            header = 'username=null, realm=myRealm, nonce=12345, uri=/, response=HASH, opaque=1, qop=auth, nc=1, cnonce=1'
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_DIGEST' => header
            )
            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            refute(backend.check(request, response)[0])
          end

          def test_check_bad_get_user_info_response2
            header = 'username=array, realm=myRealm, nonce=12345, uri=/, response=HASH, opaque=1, qop=auth, nc=1, cnonce=1'
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_DIGEST' => header
            )

            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            assert_raises(Exception) { backend.check(request, response) }
          end

          def test_check_unknown_user
            header = 'username=false, realm=myRealm, nonce=12345, uri=/, response=HASH, opaque=1, qop=auth, nc=1, cnonce=1'
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_DIGEST' => header
            )

            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            refute(backend.check(request, response)[0])
          end

          def test_check_bad_password
            header = 'username=user, realm=myRealm, nonce=12345, uri=/, response=HASH, opaque=1, qop=auth, nc=1, cnonce=1'
            request = Http::Sapi.create_from_server_array(
              'PHP_AUTH_DIGEST' => header,
              'REQUEST_METHOD'  => 'PUT'
            )

            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            refute(backend.check(request, response)[0])
          end

          def test_check
            digest_hash = Digest::MD5.hexdigest("HELLO:12345:1:1:auth:#{Digest::MD5.hexdigest('GET:/')}")
            header = "username=user, realm=myRealm, nonce=12345, uri=/, response=#{digest_hash}, opaque=1, qop=auth, nc=1, cnonce=1"
            request = Http::Sapi.create_from_server_array(
              'REQUEST_METHOD'  => 'GET',
              'PHP_AUTH_DIGEST' => header,
              'PATH_INFO'       => '/'
            )

            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            assert_equal(
              [true, 'principals/user'],
              backend.check(request, response)
            )
          end

          def test_require_auth
            request = Http::Request.new
            response = Http::Response.new

            backend = Auth::Backend::AbstractDigestMock.new
            backend.realm = 'writing unittests on a saturday night'
            backend.challenge(request, response)

            assert_equal(
              'Digest realm="writing unittests on a saturday night"',
              response.header('WWW-Authenticate')[0..51]
            )
          end
        end

        class AbstractDigestMock < AbstractDigest
          def digest_hash(_realm, user_name)
            case user_name
            when 'null'
              nil
            when 'false'
              false
            when 'array'
              []
            when 'user'
              'HELLO'
            end
          end
        end
      end
    end
  end
end
