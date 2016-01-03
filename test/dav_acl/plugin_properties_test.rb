require 'test_helper'

module Tilia
  module DavAcl
    class PluginPropertiesTest < Minitest::Test
      def test_principal_collection_set
        plugin = Plugin.new
        plugin.principal_collection_set = [
          'principals1',
          'principals2'
        ]

        requested_properties = [
          '{DAV:}principal-collection-set'
        ]

        server = Dav::ServerMock.new(Dav::SimpleCollection.new('root'))
        server.add_plugin(plugin)

        result = server.properties_for_path('', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size)
        assert_has_key('{DAV:}principal-collection-set', result[200])
        assert_kind_of(Dav::Xml::Property::Href, result[200]['{DAV:}principal-collection-set'])

        expected = [
          'principals1/',
          'principals2/'
        ]

        assert_equal(expected, result[200]['{DAV:}principal-collection-set'].hrefs)
      end

      def test_current_user_principal
        fake_server = Dav::ServerMock.new
        plugin = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        fake_server.add_plugin(plugin)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}current-user-principal'
        ]

        result = fake_server.properties_for_path('', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size)
        assert_has_key('{DAV:}current-user-principal', result[200])
        assert_kind_of(Tilia::DavAcl::Xml::Property::Principal, result[200]['{DAV:}current-user-principal'])
        assert_equal(Xml::Property::Principal::UNAUTHENTICATED, result[200]['{DAV:}current-user-principal'].type)

        # This will force the login
        fake_server.emit('beforeMethod', [fake_server.http_request, fake_server.http_response])

        result = fake_server.properties_for_path('', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size)
        assert_has_key('{DAV:}current-user-principal', result[200])
        assert_kind_of(Tilia::DavAcl::Xml::Property::Principal, result[200]['{DAV:}current-user-principal'])
        assert_equal(Xml::Property::Principal::HREF, result[200]['{DAV:}current-user-principal'].type)
        assert_equal('principals/admin/', result[200]['{DAV:}current-user-principal'].href)
      end

      def test_supported_privilege_set
        plugin = Plugin.new
        server = Dav::ServerMock.new
        server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}supported-privilege-set'
        ]

        result = server.properties_for_path('', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size)
        assert_has_key('{DAV:}supported-privilege-set', result[200])
        assert_kind_of(Xml::Property::SupportedPrivilegeSet, result[200]['{DAV:}supported-privilege-set'])

        server = Dav::ServerMock.new

        prop = result[200]['{DAV:}supported-privilege-set']
        result = server.xml.write('{DAV:}root', prop)

        xpaths = {
          '/d:root' => 1,
          '/d:root/d:supported-privilege' => 1,
          '/d:root/d:supported-privilege/d:privilege' => 1,
          '/d:root/d:supported-privilege/d:privilege/d:all' => 1,
          '/d:root/d:supported-privilege/d:abstract' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege' => 2,
          '/d:root/d:supported-privilege/d:supported-privilege/d:privilege' => 2,
          '/d:root/d:supported-privilege/d:supported-privilege/d:privilege/d:read' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:privilege/d:write' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege' => 8,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege' => 8,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:read-acl' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:read-current-user-privilege-set' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:write-content' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:write-properties' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:write-acl' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:bind' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:unbind' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:privilege/d:unlock' => 1,
          '/d:root/d:supported-privilege/d:supported-privilege/d:supported-privilege/d:abstract' => 0
        }

        dom2 = LibXML::XML::Document.string(result)

        xpaths.each do |xpath, count|
          path = dom2.find(xpath)
          assert_equal(count, path.size, "we expected #{count} appearances of #{xpath}. We found #{path.size}. Full response body: #{result}")
        end
      end

      def test_acl
        plugin = Plugin.new

        nodes = [
          MockAclNode.new(
            'foo',
            [
              {
                'principal' => 'principals/admin',
                'privilege' => '{DAV:}read'
              }
            ]
          ),
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('admin', 'principals/admin')
            ]
          )
        ]

        server = Dav::ServerMock.new(nodes)
        server.add_plugin(plugin)
        auth_plugin = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth_plugin)

        # Force login
        auth_plugin.before_method(Http::Request.new, Http::Response.new)

        requested_properties = [
          '{DAV:}acl'
        ]

        result = server.properties_for_path('foo', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size, "The {DAV:}acl property did not return from the list. Full list: #{result.inspect}")
        assert_has_key('{DAV:}acl', result[200])
        assert_kind_of(Xml::Property::Acl, result[200]['{DAV:}acl'])
      end

      def test_acl_restrictions
        plugin = Plugin.new

        nodes = [
          MockAclNode.new(
            'foo',
            [
              {
                'principal' => 'principals/admin',
                'privilege' => '{DAV:}read'
              }
            ]
          ),
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('admin', 'principals/admin')
            ]
          )
        ]

        server = Dav::ServerMock.new(nodes)
        server.add_plugin(plugin)
        auth_plugin = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth_plugin)

        # Force login
        auth_plugin.before_method(Http::Request.new, Http::Response.new)

        requested_properties = [
          '{DAV:}acl-restrictions'
        ]

        result = server.properties_for_path('foo', requested_properties)
        result = result[0]

        assert_equal(1, result[200].size, "The {DAV:}acl-restrictions property did not return from the list. Full list: #{result.inspect}")
        assert_has_key('{DAV:}acl-restrictions', result[200])
        assert_kind_of(Xml::Property::AclRestrictions, result[200]['{DAV:}acl-restrictions'])
      end

      def test_alternate_uri_set
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('user', 'principals/user')
            ]
          )
        ]

        fake_server = Dav::ServerMock.new(tree)
        # plugin = new DAV\Auth\Plugin(new DAV\Auth\Mock_backend,'realm')
        # fake_server.add_plugin(plugin)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}alternate-URI-set'
        ]
        result = fake_server.properties_for_path('principals/user', requested_properties)
        result = result[0]

        assert_has_key(200, result)
        assert_has_key('{DAV:}alternate-URI-set', result[200])
        assert_kind_of(Dav::Xml::Property::Href, result[200]['{DAV:}alternate-URI-set'])

        assert_equal([], result[200]['{DAV:}alternate-URI-set'].hrefs)
      end

      def test_principal_url
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('user', 'principals/user')
            ]
          )
        ]

        fake_server = Dav::ServerMock.new(tree)
        # plugin = new DAV\Auth\Plugin(new DAV\Auth\Mock_backend,'realm')
        # fake_server.add_plugin(plugin)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}principal-URL'
        ]

        result = fake_server.properties_for_path('principals/user', requested_properties)
        result = result[0]

        assert_has_key(200, result)
        assert_has_key('{DAV:}principal-URL', result[200])
        assert_kind_of(Dav::Xml::Property::Href, result[200]['{DAV:}principal-URL'])

        assert_equal('principals/user/', result[200]['{DAV:}principal-URL'].href)
      end

      def test_group_member_set
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('user', 'principals/user')
            ]
          )
        ]

        fake_server = Dav::ServerMock.new(tree)
        # plugin = new DAV\Auth\Plugin(new DAV\Auth\Mock_backend,'realm')
        # fake_server.add_plugin(plugin)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}group-member-set'
        ]

        result = fake_server.properties_for_path('principals/user', requested_properties)
        result = result[0]

        assert_has_key(200, result)
        assert_has_key('{DAV:}group-member-set', result[200])
        assert_kind_of(Dav::Xml::Property::Href, result[200]['{DAV:}group-member-set'])

        assert_equal([], result[200]['{DAV:}group-member-set'].hrefs)
      end

      def test_group_member_ship
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('user', 'principals/user')
            ]
          )
        ]

        fake_server = Dav::ServerMock.new(tree)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}group-membership'
        ]

        result = fake_server.properties_for_path('principals/user', requested_properties)
        result = result[0]

        assert_has_key(200, result)
        assert_has_key('{DAV:}group-membership', result[200])
        assert_kind_of(Dav::Xml::Property::Href, result[200]['{DAV:}group-membership'])

        assert_equal([], result[200]['{DAV:}group-membership'].hrefs)
      end

      def test_get_display_name
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('user', 'principals/user')
            ]
          )
        ]

        fake_server = Dav::ServerMock.new(tree)
        plugin = Plugin.new
        fake_server.add_plugin(plugin)

        requested_properties = [
          '{DAV:}displayname'
        ]

        result = fake_server.properties_for_path('principals/user', requested_properties)
        result = result[0]

        assert_has_key(200, result)
        assert_has_key('{DAV:}displayname', result[200])

        assert_equal('user', result[200]['{DAV:}displayname'])
      end
    end
  end
end
