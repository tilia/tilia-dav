require 'test_helper'

module Tilia
  module Dav
    class GetIfConditionsTest < AbstractServer
      def test_no_conditions
        request = Http::Request.new

        conditions = @server.if_conditions(request)
        assert_equal([], conditions)
      end

      def test_lock_token
        request = Http::Request.new('GET', '/path/', 'If' => '(<opaquelocktoken:token1>)')
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'path',
            'tokens' => [
              {
                'negate' => false,
                'token' => 'opaquelocktoken:token1',
                'etag' => ''
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test_not_lock_token
        server_vars = {
          'HTTP_IF'      => '(Not <opaquelocktoken:token1>)',
          'PATH_INFO'    => '/bla'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'bla',
            'tokens' => [
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => ''
              }
            ]

          }

        ]

        assert_equal(compare, conditions)
      end

      def test_lock_token_url
        server_vars = {
          'HTTP_IF' => '<http://www.example.com/> (<opaquelocktoken:token1>)'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => '',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => ''
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test2_lock_tokens
        server_vars = {
          'HTTP_IF'      => '(<opaquelocktoken:token1>) (Not <opaquelocktoken:token2>)',
          'PATH_INFO'    => '/bla'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'bla',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => ''
              },
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token2',
                'etag'   => ''
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test2_uri_lock_tokens
        server_vars = {
          'HTTP_IF' => '<http://www.example.org/node1> (<opaquelocktoken:token1>) <http://www.example.org/node2> (Not <opaquelocktoken:token2>)'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'node1',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => ''
              }
            ]
          },
          {
            'uri' => 'node2',
            'tokens' => [
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token2',
                'etag'   => ''
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test2_uri_multi_lock_tokens
        server_vars = {
          'HTTP_IF' => '<http://www.example.org/node1> (<opaquelocktoken:token1>) (<opaquelocktoken:token2>) <http://www.example.org/node2> (Not <opaquelocktoken:token3>)'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'node1',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => ''
              },
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token2',
                'etag'   => ''
              }
            ]
          },
          {
            'uri' => 'node2',
            'tokens' => [
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token3',
                'etag'   => ''
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test_etag
        server_vars = {
          'HTTP_IF'      => '(["etag1"])',
          'PATH_INFO'    => '/foo'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'foo',
            'tokens' => [
              {
                'negate' => false,
                'token'  => '',
                'etag'   => '"etag1"'
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test2_etags
        server_vars = {
          'HTTP_IF' => '<http://www.example.org/> (["etag1"]) (["etag2"])'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [

          {
            'uri' => '',
            'tokens' => [
              {
                'negate' => false,
                'token'  => '',
                'etag'   => '"etag1"'
              },
              {
                'negate' => false,
                'token'  => '',
                'etag'   => '"etag2"'
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end

      def test_complex_if
        server_vars = {
          'HTTP_IF' => '<http://www.example.org/node1> (<opaquelocktoken:token1> ["etag1"]) ' \
                        '(Not <opaquelocktoken:token2>) (["etag2"]) <http://www.example.org/node2> ' \
                        '(<opaquelocktoken:token3>) (Not <opaquelocktoken:token4>) (["etag3"])'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        conditions = @server.if_conditions(request)

        compare = [
          {
            'uri' => 'node1',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token1',
                'etag'   => '"etag1"'
              },
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token2',
                'etag'   => ''
              },
              {
                'negate' => false,
                'token'  => '',
                'etag'   => '"etag2"'
              }
            ]
          },
          {
            'uri' => 'node2',
            'tokens' => [
              {
                'negate' => false,
                'token'  => 'opaquelocktoken:token3',
                'etag'   => ''
              },
              {
                'negate' => true,
                'token'  => 'opaquelocktoken:token4',
                'etag'   => ''
              },
              {
                'negate' => false,
                'token'  => '',
                'etag'   => '"etag3"'
              }
            ]
          }
        ]

        assert_equal(compare, conditions)
      end
    end
  end
end
