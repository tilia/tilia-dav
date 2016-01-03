require 'test_helper'

module Tilia
  module Dav
    module Browser
      class PluginTest < AbstractServer
        attr_accessor :plugin

        def setup
          super
          @server.add_plugin(@plugin = Plugin.new)
          @server.tree.node_for_path('').create_directory('dir2')
        end

        def test_collection_get
          request = Http::Request.new('GET', '/dir')
          @server.http_request = request
          @server.exec

          assert_equal(200, @response.status, "Incorrect status received. Full response body: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['text/html; charset=utf-8'],
              'Content-Security-Policy' => ["img-src 'self'; style-src 'self';"]
            },
            @response.headers
          )

          body = @response.body_as_string
          assert(body.index('<title>dir'), body)
          assert(body.index('<a href="/dir/child.txt">'))
        end

        # Adding the If-None-Match should have 0 effect, but it threw an error.
        def test_collection_get_if_none_match
          request = Http::Request.new('GET', '/dir')
          request.update_header('If-None-Match', '"foo-bar"')
          @server.http_request = request
          @server.exec

          assert_equal(200, @response.status, "Incorrect status received. Full response body: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['text/html; charset=utf-8'],
              'Content-Security-Policy' => ["img-src 'self'; style-src 'self';"]
            },
            @response.headers
          )

          body = @response.body_as_string
          assert(body.index('<title>dir'), body)
          assert(body.index('<a href="/dir/child.txt">'))
        end

        def test_collection_get_root
          request = Http::Request.new('GET', '/')
          @server.http_request = request
          @server.exec

          assert_equal(200, @response.status, "Incorrect status received. Full response body: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['text/html; charset=utf-8'],
              'Content-Security-Policy' => ["img-src 'self'; style-src 'self';"]
            },
            @response.headers
          )

          body = @response.body_as_string
          assert(body.index('<title>/'), body)
          assert(body.index('<a href="/dir/">'))
          assert(body.index('<span class="btn disabled">'))
        end

        def test_get_passthru
          request = Http::Request.new('GET', '/random')
          response = Http::Response.new
          assert_nil(@plugin.http_get(request, response))
        end

        def test_post_other_content_type
          request = Http::Request.new('POST', '/', 'Content-Type' => 'text/xml')
          @server.http_request = request
          @server.exec

          assert_equal(501, @response.status)
        end

        def test_post_no_sabre_action
          request = Http::Request.new('POST', '/', 'Content-Type' => 'application/x-www-form-urlencoded')
          request.post_data = {}
          @server.http_request = request
          @server.exec

          assert_equal(501, @response.status)
        end

        def test_post_mk_col
          server_vars = {
            'REQUEST_PATH'   => '/',
            'REQUEST_METHOD' => 'POST',
            'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
          }
          post_vars = {
            'sabreAction' => 'mkcol',
            'name' => 'new_collection'
          }

          request = Http::Sapi.create_from_server_array(server_vars)
          request.post_data = post_vars
          @server.http_request = request
          @server.exec

          assert_equal(302, @response.status)
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Location' => ['/']
            },
            @response.headers
          )

          assert(::File.directory?("#{@temp_dir}/new_collection"))
        end

        def test_get_asset
          request = Http::Request.new('GET', '/?sabreAction=asset&assetName=favicon.ico')
          @server.http_request = request
          @server.exec

          assert_equal(200, @response.status, "Error: #{@response.body_as_string}")
          assert_equal(
            {
              'X-Sabre-Version' => [Version::VERSION],
              'Content-Type' => ['image/vnd.microsoft.icon'],
              'Content-Length' => [4286],
              'Cache-Control' => ['public, max-age=1209600'],
              'Content-Security-Policy' => ["img-src 'self'; style-src 'self';"]
            },
            @response.headers
          )
        end

        def test_get_asset404
          request = Http::Request.new('GET', '/?sabreAction=asset&assetName=flavicon.ico')
          @server.http_request = request
          @server.exec

          assert_equal(404, @response.status, "Error: #{@response.body_as_string}")
        end

        def test_get_asset_escape_base_path
          request = Http::Request.new('GET', '/?sabreAction=asset&assetName=./../assets/favicon.ico')
          @server.http_request = request
          @server.exec

          assert_equal(404, @response.status, "Error: #{@response.body_as_string}")
        end
      end
    end
  end
end
