require 'test_helper'

module Tilia
  module CalDav
    module Principal
      class UserTest < Minitest::Test
        def setup
          @backend = DavAcl::PrincipalBackend::Mock.new

          @backend.add_principal('uri' => 'principals/user/calendar-proxy-read')
          @backend.add_principal('uri' => 'principals/user/calendar-proxy-write')
          @backend.add_principal('uri' => 'principals/user/random')

          @user = User.new(
            @backend,
            'uri' => 'principals/user'
          )
        end

        def test_create_file
          assert_raises(Dav::Exception::Forbidden) do
            @user.create_file('test')
          end
        end

        def test_create_directory
          assert_raises(Dav::Exception::Forbidden) do
            @user.create_directory('test')
          end
        end

        def test_get_child_proxy_read
          child = @user.child('calendar-proxy-read')
          assert_kind_of(ProxyRead, child)
        end

        def test_get_child_proxy_write
          child = @user.child('calendar-proxy-write')
          assert_kind_of(ProxyWrite, child)
        end

        def test_get_child_not_found
          assert_raises(Dav::Exception::NotFound) do
            child = @user.child('foo')
          end
        end

        def test_get_child_not_found2
          assert_raises(Dav::Exception::NotFound) do
            child = @user.child('random')
          end
        end

        def test_get_children
          children = @user.children
          assert_equal(2, children.size)
          assert_kind_of(ProxyRead, children[0])
          assert_kind_of(ProxyWrite, children[1])
        end

        def test_child_exist
          assert(@user.child_exists('calendar-proxy-read'))
          assert(@user.child_exists('calendar-proxy-write'))
          refute(@user.child_exists('foo'))
        end

        def test_get_acl
          expected = [
            {
              'privilege' => '{DAV:}read',
              'principal' => '{DAV:}authenticated',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => 'principals/user/calendar-proxy-read',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}read',
              'principal' => 'principals/user/calendar-proxy-write',
              'protected' => true
            }
          ]

          assert_equal(expected, @user.acl)
        end
      end
    end
  end
end
