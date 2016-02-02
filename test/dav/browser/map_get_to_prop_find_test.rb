require 'test_helper'

module Tilia
  module Dav
    module Browser
      class MapGetToPropFindTest < AbstractServer
        def setup
          super
          @server.add_plugin(MapGetToPropFind.new)
        end

        def test_collection_get
          server_vars = {
            'PATH_INFO'      => '/',
            'REQUEST_METHOD' => 'GET'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.body = ''
          @server.http_request = request
          @server.exec

          assert_equal(207, @response.status, "Incorrect status response received. Full response body: #{@response.body}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['application/xml; charset=utf-8'],
              'DAV' => ['1, 3, extended-mkcol'],
              'Vary' => ['Brief,Prefer']
            },
            @response.headers
          )
        end
      end
    end
  end
end
