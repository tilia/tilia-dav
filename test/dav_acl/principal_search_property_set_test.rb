require 'test_helper'

module Tilia
  module DavAcl
    class PrincipalSearchPropertySetTest < Minitest::Test
      def setup
        backend = PrincipalBackend::Mock.new

        dir = Dav::SimpleCollection.new('root')
        principals = PrincipalCollection.new(backend)
        dir.add_child(principals)

        @server = Dav::ServerMock.new(dir)
        @server.sapi = Http::SapiMock.new
        @server.http_response = Http::ResponseMock.new
        plugin = Plugin.new
        assert_kind_of(Plugin, plugin)
        @server.add_plugin(plugin)
        assert_equal(plugin, @server.plugin('acl'))
      end

      def test_depth1
        xml = <<XML
<?xml version="1.0"?>
<d:principal-search-property-set xmlns:d="DAV:" />
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '1',
          'REQUEST_PATH'   => '/principals'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(400, @server.http_response.status)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )
      end

      def test_depth_incorrect_xml
        xml = <<XML
<?xml version="1.0"?>
<d:principal-search-property-set xmlns:d="DAV:">
  <d:ohell />
</d:principal-search-property-set>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
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

      def test_correct
        xml = <<XML
<?xml version="1.0"?>
<d:principal-search-property-set xmlns:d="DAV:"/>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'REQUEST_PATH'   => '/principals'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(200, @server.http_response.status, @server.http_response.body_as_string)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )

        check = {
          '/d:principal-search-property-set' => 1,
          '/d:principal-search-property-set/d:principal-search-property' => 2,
          '/d:principal-search-property-set/d:principal-search-property/d:prop' => 2,
          '/d:principal-search-property-set/d:principal-search-property/d:prop/d:displayname' => 1,
          '/d:principal-search-property-set/d:principal-search-property/d:prop/s:email-address' => 1,
          '/d:principal-search-property-set/d:principal-search-property/d:description' => 2
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end
    end
  end
end
