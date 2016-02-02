require 'test_helper'

module Tilia
  module DavAcl
    class ExpandPropertiesTest < Minitest::Test
      def setup
        tree = [
          Dav::Mock::PropertiesCollection.new(
            'node1',
            [],
            '{http://sabredav.org/ns}simple' => 'foo',
            '{http://sabredav.org/ns}href'   => Dav::Xml::Property::Href.new('node2'),
            '{DAV:}displayname'     => 'Node 1'
          ),
          Dav::Mock::PropertiesCollection.new(
            'node2',
            [],
            '{http://sabredav.org/ns}simple' => 'simple',
            '{http://sabredav.org/ns}hreflist' => Dav::Xml::Property::Href.new(['node1', 'node3']),
            '{DAV:}displayname'     => 'Node 2'
          ),
          Dav::Mock::PropertiesCollection.new(
            'node3',
            [],
            '{http://sabredav.org/ns}simple' => 'simple',
            '{DAV:}displayname'     => 'Node 3'
          )
        ]

        @server = Dav::ServerMock.new(tree)
        @server.sapi = Http::SapiMock.new
        @server.debug_exceptions = true
        @server.http_response = Http::ResponseMock.new

        plugin = Plugin.new
        plugin.allow_access_to_nodes_without_acl = true

        assert_kind_of(Plugin, plugin)
        @server.add_plugin(plugin)
        assert_equal(plugin, @server.plugin('acl'))
      end

      def test_simple
        xml = <<XML
<?xml version="1.0"?>
<d:expand-property xmlns:d="DAV:">
  <d:property name="displayname" />
  <d:property name="foo" namespace="http://www.sabredav.org/NS/2010/nonexistant" />
  <d:property name="simple" namespace="http://sabredav.org/ns" />
  <d:property name="href" namespace="http://sabredav.org/ns" />
</d:expand-property>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'PATH_INFO'      => '/node1'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, "Incorrect status code received. Full body: #{@server.http_response.body_as_string}")
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 1,
          '/d:multistatus/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/d:displayname' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:simple' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:href' => 1
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      def test_expand
        xml = <<XML
<?xml version="1.0"?>
<d:expand-property xmlns:d="DAV:">
  <d:property name="href" namespace="http://sabredav.org/ns">
      <d:property name="displayname" />
  </d:property>
</d:expand-property>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'PATH_INFO'      => '/node1'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status, "Incorrect response status received. Full response body: #{@server.http_response.body_as_string}")
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 1,
          '/d:multistatus/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:response' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:response/d:propstat' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:response/d:propstat/d:prop' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:href/d:response/d:propstat/d:prop/d:displayname' => 1
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      # @depends testSimple
      def test_expand_href_list
        xml = <<XML
<?xml version="1.0"?>
<d:expand-property xmlns:d="DAV:">
  <d:property name="hreflist" namespace="http://sabredav.org/ns">
      <d:property name="displayname" />
  </d:property>
</d:expand-property>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'PATH_INFO'      => '/node2'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 1,
          '/d:multistatus/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:href' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/d:displayname' => 2
        }

        xml = LibXML::XML::Document.string(@server.http_response.body_as_string)

        check.each do |xpath, count|
          result = xml.find(xpath)
          assert_equal(count, result.size, "we expected #{count} appearances of #{xpath}. We found #{result.size}. Full response body: #{@server.http_response.body_as_string}")
        end
      end

      def test_expand_deep
        xml = <<XML
<?xml version="1.0"?>
<d:expand-property xmlns:d="DAV:">
  <d:property name="hreflist" namespace="http://sabredav.org/ns">
      <d:property name="href" namespace="http://sabredav.org/ns">
          <d:property name="displayname" />
      </d:property>
      <d:property name="displayname" />
  </d:property>
</d:expand-property>
XML

        server_vars = {
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_DEPTH'     => '0',
          'PATH_INFO'      => '/node2'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = xml

        @server.http_request = request
        @server.exec

        assert_equal(207, @server.http_response.status)
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Type' => ['application/xml; charset=utf-8']
          },
          @server.http_response.headers
        )

        check = {
          '/d:multistatus' => 1,
          '/d:multistatus/d:response' => 1,
          '/d:multistatus/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:href' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat' => 3,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop' => 3,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/d:displayname' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href' => 2,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href/d:response' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href/d:response/d:href' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href/d:response/d:propstat' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href/d:response/d:propstat/d:prop' => 1,
          '/d:multistatus/d:response/d:propstat/d:prop/s:hreflist/d:response/d:propstat/d:prop/s:href/d:response/d:propstat/d:prop/d:displayname' => 1
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
