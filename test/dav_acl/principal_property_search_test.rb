require 'test_helper'

module Tilia
  module DavAcl
    class PrincipalPropertySearchTest < Minitest::Test
      def setup
        backend = PrincipalBackend::Mock.new

        dir = Dav::SimpleCollection.new('root')
        principals = PrincipalCollection.new(backend)
        dir.add_child(principals)

        @server = Dav::ServerMock.new(dir)
        @server.sapi = Http::SapiMock.new
        @server.http_response = Http::ResponseMock.new
        @server.debug_exceptions = true
        plugin = MockPlugin.new
        plugin.allow_access_to_nodes_without_acl = true
        assert_kind_of(Plugin, plugin)
        @server.add_plugin(plugin)
        assert_equal(plugin, @server.plugin('acl'))
      end

      def test_depth1
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:">
  <d:property-search>
     <d:prop>
       <d:displayname />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '1',
          'REQUEST_PATH'   => '/principals'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(400, @server.http_response.status, @server.http_response.body_as_string)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )
      end

      def test_unknown_search_field
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:">
  <d:property-search>
     <d:prop>
       <d:yourmom />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/principals'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, "Full body: #{@server.http_response.body_as_string}")
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Vary'         => ['Brief,Prefer']
          },
          @server.http_response.headers
        )
      end

      def test_correct
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:">
  <d:apply-to-principal-collection-set />
  <d:property-search>
     <d:prop>
       <d:displayname />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, @server.http_response.body)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Vary'         => ['Brief,Prefer']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 2,
          '/d:multistatus/d:response/d:href' => 2,
          '/d:multistatus/d:response/d:propstat' => 4,
          '/d:multistatus/d:response/d:propstat/d:prop' => 4,
          '/d:multistatus/d:response/d:propstat/d:prop/d:displayname' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/d:getcontentlength' => 2,
          '/d:multistatus/d:response/d:propstat/d:status' => 4
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      def test_and
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:">
  <d:apply-to-principal-collection-set />
  <d:property-search>
     <d:prop>
       <d:displayname />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:property-search>
     <d:prop>
       <d:foo />
     </d:prop>
     <d:match>bar</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, @server.http_response.body_as_string)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Vary'         => ['Brief,Prefer']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 0,
          '/d:multistatus/d:response/d:href' => 0,
          '/d:multistatus/d:response/d:propstat' => 0,
          '/d:multistatus/d:response/d:propstat/d:prop' => 0,
          '/d:multistatus/d:response/d:propstat/d:prop/d:displayname' => 0,
          '/d:multistatus/d:response/d:propstat/d:prop/d:getcontentlength' => 0,
          '/d:multistatus/d:response/d:propstat/d:status' => 0
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      def test_or
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:" test="anyof">
  <d:apply-to-principal-collection-set />
  <d:property-search>
     <d:prop>
       <d:displayname />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:property-search>
     <d:prop>
       <d:foo />
     </d:prop>
     <d:match>bar</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, @server.http_response.body_as_string)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Vary'         => ['Brief,Prefer']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 2,
          '/d:multistatus/d:response/d:href' => 2,
          '/d:multistatus/d:response/d:propstat' => 4,
          '/d:multistatus/d:response/d:propstat/d:prop' => 4,
          '/d:multistatus/d:response/d:propstat/d:prop/d:displayname' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/d:getcontentlength' => 2,
          '/d:multistatus/d:response/d:propstat/d:status' => 4
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      def test_wrong_uri
        xml = <<BODY
<?xml version="1.0"?>
<d:principal-property-search xmlns:d="DAV:">
  <d:property-search>
     <d:prop>
       <d:displayname />
     </d:prop>
     <d:match>user</d:match>
  </d:property-search>
  <d:prop>
    <d:displayname />
    <d:getcontentlength />
  </d:prop>
</d:principal-property-search>
BODY

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, @server.http_response.body_as_string)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8'],
            'Vary'         => ['Brief,Prefer']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 0
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      class MockPlugin < Plugin
        def current_user_privilege_set(_node)
          [
            '{DAV:}read',
            '{DAV:}write'
          ]
        end
      end
    end
  end
end
