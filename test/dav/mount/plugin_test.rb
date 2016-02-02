require 'test_helper'

module Tilia
  module Dav
    module Mount
      class PluginTest < AbstractServer
        def setup
          super
          @server.add_plugin(Plugin.new)
        end

        def test_pass_through
          server_vars = {
            'PATH_INFO'      => '/',
            'REQUEST_METHOD' => 'GET'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = (request)
          @server.exec

          assert_equal(501, @response.status, "We expected GET to not be implemented for Directories. Response body: #{@response.body_as_string}")
        end

        def test_mount_response
          server_vars = {
            'PATH_INFO'      => '/',
            'REQUEST_METHOD' => 'GET',
            'QUERY_STRING'   => 'mount',
            'HTTP_HOST'      => 'example.org'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          @server.http_request = (request)
          @server.exec

          assert_equal(200, @response.status)

          body = @response.body.gsub(/xmlns(:[A-Za-z0-9_])?=("|')DAV:("|')/) { "xmlns#{Regexp.last_match(1)}=\"urn:DAV\"" }
          xml = LibXML::XML::Document.string(body)

          url = xml.find('//dm:url')
          assert_equal('http://example.org/', url[0].content)
        end
      end
    end
  end
end
