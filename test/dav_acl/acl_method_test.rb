require 'test_helper'

module Tilia
  module DavAcl
    class ACLMethodTest < Minitest::Test
      def test_callback
        acl = Plugin.new
        server = Dav::ServerMock.new
        server.add_plugin(acl)
        server.http_request = Http::Request.new('GET', '')

        assert_raises(Dav::Exception::BadRequest) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_not_supported_by_node
        tree = [Dav::SimpleCollection.new('test')]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('GET', '')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Dav::Exception::MethodNotAllowed) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_success_simple
        tree = [MockAclNode.new('test', [])]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('GET', '/test')

        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        refute(acl.http_acl(server.http_request, server.http_response))
      end

      # @expectedException Tilia::DavAcl::Exception\NotRecognizedPrincipal
      def test_unrecognized_principal
        tree = [MockAclNode.new('test', [])]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:read /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notfound</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::NotRecognizedPrincipal) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_unrecognized_principal2
        tree = [
          MockAclNode.new('test', []),
          Dav::SimpleCollection.new(
            'principals',
            [Dav::SimpleCollection.new('notaprincipal')]
          )
        ]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:read /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notaprincipal</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::NotRecognizedPrincipal) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_unknown_privilege
        tree = [MockAclNode.new('test', [])]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:bananas /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notfound</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::NotSupportedPrivilege) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_abstract_privilege
        tree = [MockAclNode.new('test', [])]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:all /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notfound</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::NoAbstract) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_update_protected_privilege
        old_acl = [
          {
            'principal' => 'principals/notfound',
            'privilege' => '{DAV:}write',
            'protected' => true
          }
        ]
        tree = [MockAclNode.new('test', old_acl)]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:read /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notfound</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::AceConflict) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_update_protected_privilege2
        old_acl = [
          {
            'principal' => 'principals/notfound',
            'privilege' => '{DAV:}write',
            'protected' => true
          }
        ]
        tree = [MockAclNode.new('test', old_acl)]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:write /></d:privilege></d:grant>
    <d:principal><d:href>/principals/foo</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::AceConflict) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_update_protected_privilege3
        old_acl = [
          {
            'principal' => 'principals/notfound',
            'privilege' => '{DAV:}write',
            'protected' => true
          }
        ]
        tree = [MockAclNode.new('test', old_acl)]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:write /></d:privilege></d:grant>
    <d:principal><d:href>/principals/notfound</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        assert_raises(Exception::AceConflict) { acl.http_acl(server.http_request, server.http_response) }
      end

      def test_success_complex
        old_acl = [
          {
            'principal' => 'principals/foo',
            'privilege' => '{DAV:}write',
            'protected' => true
          },
          {
            'principal' => 'principals/bar',
            'privilege' => '{DAV:}read'
          }
        ]
        node = MockAclNode.new('test', old_acl)
        tree = [
          node,
          Dav::SimpleCollection.new(
            'principals',
            [
              MockPrincipal.new('foo', 'principals/foo'),
              MockPrincipal.new('baz', 'principals/baz')
            ]
          )
        ]

        acl = Plugin.new
        server = Dav::ServerMock.new(tree)
        server.http_request = Http::Request.new('ACL', '/test')
        body = <<BODY
<?xml version="1.0"?>
<d:acl xmlns:d="DAV:">
  <d:ace>
    <d:grant><d:privilege><d:write /></d:privilege></d:grant>
    <d:principal><d:href>/principals/foo</d:href></d:principal>
    <d:protected />
  </d:ace>
  <d:ace>
    <d:grant><d:privilege><d:write /></d:privilege></d:grant>
    <d:principal><d:href>/principals/baz</d:href></d:principal>
  </d:ace>
</d:acl>
BODY

        server.http_request.body = body
        server.add_plugin(acl)

        refute(acl.http_acl(server.http_request, server.http_response))

        assert_equal(
          [
            {
              'principal' => 'principals/foo',
              'privilege' => '{DAV:}write',
              'protected' => true
            },
            {
              'principal' => 'principals/baz',
              'privilege' => '{DAV:}write',
              'protected' => false
            }
          ],
          node.acl
        )
      end
    end
  end
end
