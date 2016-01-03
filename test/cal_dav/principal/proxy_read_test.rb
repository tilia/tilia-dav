require 'test_helper'

module Tilia
  module CalDav
    module Principal
      class ProxyReadTest < Minitest::Test
        def setup
          @backend = DavAcl::PrincipalBackend::Mock.new
          @principal = ProxyRead.new(
            @backend,
            'uri' => 'principal/user'
          )
        end

        def test_get_name
          assert_equal('calendar-proxy-read', @principal.name)
        end

        def test_get_display_name
          assert_equal('calendar-proxy-read', @principal.display_name)
        end

        def test_get_last_modified
          assert_nil(@principal.last_modified)
        end

        def test_delete
          assert_raises(Dav::Exception::Forbidden) do
            @principal.delete
          end
        end

        def test_set_name
          assert_raises(Dav::Exception::Forbidden) do
            @principal.name = 'foo'
          end
        end

        def test_get_alternate_uri_set
          assert_equal([], @principal.alternate_uri_set)
        end

        def test_get_principal_uri
          assert_equal('principal/user/calendar-proxy-read', @principal.principal_url)
        end

        def test_get_group_member_set
          assert_equal([], @principal.group_member_set)
        end

        def test_get_group_membership
          assert_equal([], @principal.group_membership)
        end

        def test_set_group_member_set
          @principal.group_member_set = ['principals/foo']

          expected = {
            @principal.principal_url => ['principals/foo']
          }

          assert_equal(expected, @backend.group_members)
        end
      end
    end
  end
end
