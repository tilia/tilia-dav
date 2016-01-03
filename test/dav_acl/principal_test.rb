require 'test_helper'

module Tilia
  module DavAcl
    class PrincipalTest < Minitest::Test
      def test_construct
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_kind_of(Principal, principal)
      end

      # @expectedException Sabre\DAV\Exception
      def test_construct_no_uri
        principal_backend = PrincipalBackend::Mock.new
        assert_raises(Dav::Exception) { Principal.new(principal_backend, {}) }
      end

      def test_get_name
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal('admin', principal.name)
      end

      def test_get_display_name
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal('admin', principal.displayname)

        principal = Principal.new(
          principal_backend,
          'uri' => 'principals/admin',
          '{DAV:}displayname' => 'Mr. Admin'
        )
        assert_equal('Mr. Admin', principal.displayname)
      end

      def test_get_properties
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(
          principal_backend,
          'uri' => 'principals/admin',
          '{DAV:}displayname' => 'Mr. Admin',
          '{http://www.example.org/custom}custom' => 'Custom',
          '{http://sabredav.org/ns}email-address' => 'admin@example.org'
        )

        keys = [
          '{DAV:}displayname',
          '{http://www.example.org/custom}custom',
          '{http://sabredav.org/ns}email-address'
        ]
        props = principal.properties(keys)

        keys.each do |key|
          assert_has_key(key, props)
        end

        assert_equal('Mr. Admin', props['{DAV:}displayname'])

        assert_equal('admin@example.org', props['{http://sabredav.org/ns}email-address'])
      end

      def test_update_properties
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')

        prop_patch = Dav::PropPatch.new('{DAV:}yourmom' => 'test')

        result = principal.prop_patch(prop_patch)
        result = prop_patch.commit
        assert(result)
      end

      def test_get_principal_url
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal('principals/admin', principal.principal_url)
      end

      def test_get_alternate_uri_set
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(
          principal_backend,
          'uri' => 'principals/admin',
          '{DAV:}displayname' => 'Mr. Admin',
          '{http://www.example.org/custom}custom' => 'Custom',
          '{http://sabredav.org/ns}email-address' => 'admin@example.org',
          '{DAV:}alternate-URI-set' => [
            'mailto:admin+1@example.org',
            'mailto:admin+2@example.org',
            'mailto:admin@example.org'
          ]
        )

        expected = [
          'mailto:admin+1@example.org',
          'mailto:admin+2@example.org',
          'mailto:admin@example.org'
        ]

        assert_equal(expected, principal.alternate_uri_set)
      end

      def test_get_alternate_uri_set_empty
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(
          principal_backend,
          'uri' => 'principals/admin'
        )

        expected = []

        assert_equal(expected, principal.alternate_uri_set)
      end

      def test_get_group_member_set
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal([], principal.group_member_set)
      end

      def test_get_group_membership
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal([], principal.group_membership)
      end

      def test_set_group_member_set
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        principal.group_member_set = ['principals/foo']

        assert_equal(
          {
            'principals/admin' => ['principals/foo']
          },
          principal_backend.group_members
        )
      end

      def test_get_owner
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal('principals/admin', principal.owner)
      end

      def test_get_group
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_nil(principal.group)
      end

      def test_get_acl
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_equal(
          [
            {
              'privilege' => '{DAV:}read',
              'principal' => '{DAV:}authenticated',
              'protected' => true
            }
          ],
          principal.acl
        )
      end

      def test_set_acl
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_raises(Dav::Exception::MethodNotAllowed) { principal.acl = [] }
      end

      def test_get_supported_privilege_set
        principal_backend = PrincipalBackend::Mock.new
        principal = Principal.new(principal_backend, 'uri' => 'principals/admin')
        assert_nil(principal.supported_privilege_set)
      end
    end
  end
end
