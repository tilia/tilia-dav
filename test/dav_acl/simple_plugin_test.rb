require 'test_helper'

module Tilia
  module DavAcl
    class SimplePluginTest < Minitest::Test
      def test_values
        acl_plugin = Plugin.new
        assert_equal('acl', acl_plugin.plugin_name)
        assert_equal(
          ['access-control', 'calendarserver-principal-property-search'],
          acl_plugin.features
        )

        assert_equal(
          [
            '{DAV:}expand-property',
            '{DAV:}principal-property-search',
            '{DAV:}principal-search-property-set'
          ],
          acl_plugin.supported_report_set(''))

        assert_equal(['ACL'], acl_plugin.methods(''))

        assert_equal(
          'acl',
          acl_plugin.plugin_info['name']
        )
      end

      def test_get_flat_privilege_set
        expected = {
          '{DAV:}all' => {
            'privilege' => '{DAV:}all',
            'abstract' => true,
            'aggregates' => [
              '{DAV:}read',
              '{DAV:}write'
            ],
            'concrete' => nil
          },
          '{DAV:}read' => {
            'privilege' => '{DAV:}read',
            'abstract' => false,
            'aggregates' => [
              '{DAV:}read-acl',
              '{DAV:}read-current-user-privilege-set'
            ],
            'concrete' => '{DAV:}read'
          },
          '{DAV:}read-acl' => {
            'privilege' => '{DAV:}read-acl',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}read-acl'
          },
          '{DAV:}read-current-user-privilege-set' => {
            'privilege' => '{DAV:}read-current-user-privilege-set',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}read-current-user-privilege-set'
          },
          '{DAV:}write' => {
            'privilege' => '{DAV:}write',
            'abstract' => false,
            'aggregates' => [
              '{DAV:}write-acl',
              '{DAV:}write-properties',
              '{DAV:}write-content',
              '{DAV:}bind',
              '{DAV:}unbind',
              '{DAV:}unlock'
            ],
            'concrete' => '{DAV:}write'
          },
          '{DAV:}write-acl' => {
            'privilege' => '{DAV:}write-acl',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}write-acl'
          },
          '{DAV:}write-properties' => {
            'privilege' => '{DAV:}write-properties',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}write-properties'
          },
          '{DAV:}write-content' => {
            'privilege' => '{DAV:}write-content',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}write-content'
          },
          '{DAV:}unlock' => {
            'privilege' => '{DAV:}unlock',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}unlock'
          },
          '{DAV:}bind' => {
            'privilege' => '{DAV:}bind',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}bind'
          },
          '{DAV:}unbind' => {
            'privilege' => '{DAV:}unbind',
            'abstract' => false,
            'aggregates' => [],
            'concrete' => '{DAV:}unbind'
          }
        }

        plugin = Plugin.new
        server = Dav::ServerMock.new
        server.add_plugin(plugin)
        assert_equal(expected, plugin.flat_privilege_set(''))
      end

      def test_current_user_principals_not_logged_in
        acl = Plugin.new
        server = Dav::ServerMock.new
        server.add_plugin(acl)

        assert_equal([], acl.current_user_principals)
      end

      def test_current_user_principals_simple
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('admin', 'principals/admin')
            ]
          )
        ]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.add_plugin(acl)

        auth = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth)

        # forcing login
        auth.before_method(Http::Request.new, Http::Response.new)

        assert_equal(['principals/admin'], acl.current_user_principals)
      end

      def test_current_user_principals_groups
        tree = [
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new(
                'admin',
                'principals/admin',
                ['principals/administrators', 'principals/everyone']
              ),
              MockPrincipal.new(
                'administrators',
                'principals/administrators',
                ['principals/groups'],
                ['principals/admin']
              ),
              MockPrincipal.new(
                'everyone',
                'principals/everyone',
                [],
                ['principals/admin']
              ),
              MockPrincipal.new(
                'groups',
                'principals/groups',
                [],
                ['principals/administrators']
              )
            ]
          )
        ]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.add_plugin(acl)

        auth = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth)

        # forcing login
        auth.before_method(Http::Request.new, Http::Response.new)

        expected = [
          'principals/admin',
          'principals/administrators',
          'principals/everyone',
          'principals/groups'
        ]

        assert_equal(expected, acl.current_user_principals)

        # The second one should trigger the cache and be identical
        assert_equal(expected, acl.current_user_principals)
      end

      def test_get_acl
        acl = [
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}read'
          },
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}write'
          }
        ]

        tree = [
          MockAclNode.new('foo', acl)
        ]

        server = Dav::ServerMock.new(tree)
        acl_plugin = Plugin.new
        server.add_plugin(acl_plugin)

        assert_equal(acl, acl_plugin.acl('foo'))
      end

      def test_current_user_privilege_set
        acl = [
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}read'
          },
          {
            'principal' => 'principals/user1',
            'privilege' => '{DAV:}read'
          },
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}write'
          }
        ]

        tree = [
          MockAclNode.new('foo', acl),
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('admin', 'principals/admin')
            ]
          )
        ]

        server = Dav::ServerMock.new(tree)
        acl_plugin = Plugin.new
        server.add_plugin(acl_plugin)

        auth = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth)

        # forcing login
        auth.before_method(Http::Request.new, Http::Response.new)

        expected = [
          '{DAV:}write',
          '{DAV:}write-acl',
          '{DAV:}write-properties',
          '{DAV:}write-content',
          '{DAV:}bind',
          '{DAV:}unbind',
          '{DAV:}unlock',
          '{DAV:}read',
          '{DAV:}read-acl',
          '{DAV:}read-current-user-privilege-set'
        ]

        assert_equal(expected, acl_plugin.current_user_privilege_set('foo'))
      end

      def test_check_privileges
        acl = [
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}read'
          },
          {
            'principal' => 'principals/user1',
            'privilege' => '{DAV:}read'
          },
          {
            'principal' => 'principals/admin',
            'privilege' => '{DAV:}write'
          }
        ]

        tree = [
          MockAclNode.new('foo', acl),
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('admin', 'principals/admin')
            ]
          )
        ]

        server = Dav::ServerMock.new(tree)
        acl_plugin = Plugin.new
        server.add_plugin(acl_plugin)

        auth = Dav::Auth::Plugin.new(Dav::Auth::Backend::Mock.new)
        server.add_plugin(auth)

        # forcing login
        # auth.before_method('GET','/')

        refute(acl_plugin.check_privileges('foo', ['{DAV:}read'], Plugin::R_PARENT, false))
      end
    end
  end
end
