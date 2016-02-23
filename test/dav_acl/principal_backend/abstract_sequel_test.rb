module Tilia
  module DavAcl
    module PrincipalBackend
      module AbstractSequelTest
        def sequel
        end

        def test_construct
          db = sequel
          backend = Sequel.new(db)
          assert_kind_of(Sequel, backend)
        end

        def test_get_principals_by_prefix
          db = sequel
          backend = Sequel.new(db)

          expected = [
            {
              'uri' => 'principals/user',
              '{http://sabredav.org/ns}email-address' => 'user@example.org',
              '{DAV:}displayname' => 'User'
            },
            {
              'uri' => 'principals/group',
              '{http://sabredav.org/ns}email-address' => 'group@example.org',
              '{DAV:}displayname' => 'Group'
            }
          ]

          assert_equal(expected, backend.principals_by_prefix('principals'))
          assert_equal([], backend.principals_by_prefix('foo'))
        end

        def test_get_principal_by_path
          db = sequel
          backend = Sequel.new(db)

          expected = {
            'id' => 1,
            'uri' => 'principals/user',
            '{http://sabredav.org/ns}email-address' => 'user@example.org',
            '{DAV:}displayname' => 'User'
          }

          assert_equal(expected, backend.principal_by_path('principals/user'))
          assert_nil(backend.principal_by_path('foo'))
        end

        def test_get_group_member_set
          db = sequel
          backend = Sequel.new(db)
          expected = ['principals/user']

          assert_equal(expected, backend.group_member_set('principals/group'))
        end

        def test_get_group_membership
          db = sequel
          backend = Sequel.new(db)
          expected = ['principals/group']

          assert_equal(expected, backend.group_membership('principals/user'))
        end

        def test_set_group_member_set
          db = sequel

          # Start situation
          backend = Sequel.new(db)
          assert_equal(['principals/user'], backend.group_member_set('principals/group'))

          # Removing all principals
          backend.update_group_member_set('principals/group', [])
          assert_equal([], backend.group_member_set('principals/group'))

          # Adding principals again
          backend.update_group_member_set('principals/group', ['principals/user'])
          assert_equal(['principals/user'], backend.group_member_set('principals/group'))
        end

        def test_search_principals
          db = sequel

          backend = Sequel.new(db)

          result = backend.search_principals('principals', '{DAV:}blabla' => 'foo')
          assert_equal([], result)

          result = backend.search_principals('principals', '{DAV:}displayname' => 'ou')
          assert_equal(['principals/group'], result)

          result = backend.search_principals('principals', '{DAV:}displayname' => 'UsEr', '{http://sabredav.org/ns}email-address' => 'USER@EXAMPLE')
          assert_equal(['principals/user'], result)

          result = backend.search_principals('mom', '{DAV:}displayname' => 'UsEr', '{http://sabredav.org/ns}email-address' => 'USER@EXAMPLE')
          assert_equal([], result)
        end

        def test_update_principal
          db = sequel
          backend = Sequel.new(db)

          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'pietje'
          )

          backend.update_principal('principals/user', prop_patch)
          result = prop_patch.commit

          assert(result)

          assert_equal(
            {
              'id' => 1,
              'uri' => 'principals/user',
              '{DAV:}displayname' => 'pietje',
              '{http://sabredav.org/ns}email-address' => 'user@example.org'
            },
            backend.principal_by_path('principals/user')
          )
        end

        def test_update_principal_unknown_field
          db = sequel
          backend = Sequel.new(db)

          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'pietje',
            '{DAV:}unknown' => 'foo'
          )

          backend.update_principal('principals/user', prop_patch)
          result = prop_patch.commit

          refute(result)

          assert_equal(
            {
              '{DAV:}displayname' => 424,
              '{DAV:}unknown' => 403
            },
            prop_patch.result
          )

          assert_equal(
            {
              'id' => 1,
              'uri' => 'principals/user',
              '{DAV:}displayname' => 'User',
              '{http://sabredav.org/ns}email-address' => 'user@example.org'
            },
            backend.principal_by_path('principals/user')
          )
        end

        def test_find_by_uri_unknown_scheme
          db = sequel
          backend = Sequel.new(db)
          assert_nil(backend.find_by_uri('http://foo', 'principals'))
        end

        def test_find_by_uri
          db = sequel
          backend = Sequel.new(db)

          assert_equal(
            'principals/user',
            backend.find_by_uri('mailto:user@example.org', 'principals')
          )
        end
      end
    end
  end
end
