require 'test_helper'

module Tilia
  module Dav
    module PartialUpdate
      class PluginTest < DavServerTest
        def setup
          @node = FileMock.new
          @tree = [@node]

          super

          @plugin = Plugin.new
          @server.add_plugin(@plugin)
        end

        def test_init
          assert_equal('partialupdate', @plugin.plugin_name)
          assert_equal(['sabredav-partialupdate'], @plugin.features)
          assert_equal(['PATCH'], @plugin.http_methods('partial'))
          assert_equal([], @plugin.http_methods(''))
        end

        def test_patch_no_range
          @node.put('aaaaaaaa')
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'PATCH',
            'PATH_INFO'      => '/partial'
          )
          response = request(request)

          assert_equal(400, response.status, "Full response body: #{response.body_as_string}")
        end

        def test_patch_not_supported
          @node.put('aaaaaaaa')
          request = Http::Request.new(
            'PATCH',
            '/',
            'X-Update-Range' => '3-4'
          )
          request.body = 'bbb'
          response = request(request)

          assert_equal(405, response.status, "Full response body: #{response.body_as_string}")
        end

        def test_patch_no_content_type
          @node.put('aaaaaaaa')
          request = Http::Request.new(
            'PATCH',
            '/partial',
            'X-Update-Range' => 'bytes=3-4'
          )
          request.body = 'bbb'
          response = request(request)

          assert_equal(415, response.status, "Full response body: #{response.body_as_string}")
        end

        def test_patch_bad_range
          @node.put('aaaaaaaa')
          request = Http::Request.new(
            'PATCH',
            '/partial',
            'X-Update-Range' => 'bytes=3-4',
            'Content-Type' => 'application/x-sabredav-partialupdate',
            'Content-Length' => '3'
          )
          request.body = 'bbb'
          response = request(request)

          assert_equal(416, response.status, "Full response body: #{response.body_as_string}")
        end

        def test_patch_no_length
          @node.put('aaaaaaaa')
          request = Http::Request.new(
            'PATCH',
            '/partial',
            'X-Update-Range' => 'bytes=3-5',
            'Content-Type' => 'application/x-sabredav-partialupdate'
          )
          request.body = 'bbb'
          response = request(request)

          assert_equal(411, response.status, "Full response body: #{response.body_as_string}")
        end

        def test_patch_success
          @node.put('aaaaaaaa')
          request = Http::Request.new(
            'PATCH',
            '/partial',
            'X-Update-Range' => 'bytes=3-5',
            'Content-Type' => 'application/x-sabredav-partialupdate',
            'Content-Length' => 3
          )
          request.body = 'bbb'
          response = request(request)

          assert_equal(204, response.status, "Full response body: #{response.body_as_string}")
          assert_equal('aaabbbaa', @node.get)
        end

        def test_patch_no_end_range
          @node.put('aaaaa')
          request = Http::Request.new(
            'PATCH',
            '/partial',
            'X-Update-Range' => 'bytes=3-',
            'Content-Type' => 'application/x-sabredav-partialupdate',
            'Content-Length' => '3'
          )
          request.body = 'bbb'

          response = request(request)

          assert_equal(204, response.status, "Full response body: #{response.body_as_string}")
          assert_equal('aaabbb', @node.get)
        end
      end
    end
  end
end
