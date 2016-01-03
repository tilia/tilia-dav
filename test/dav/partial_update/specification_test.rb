require 'test_helper'

module Tilia
  module Dav
    module PartialUpdate
      # This test is an end-to-end sabredav test that goes through all
      # the cases in the specification.
      #
      # See: http://sabre.io/dav/http-patch/
      class SpecificationTest < Minitest::Test
        def setup
          @temp_dir = Dir.mktmpdir

          @node = FsExt::File.new("#{@temp_dir}/foobar.txt")
          @server = ServerMock.new([@node])
          @server.debug_exceptions = true
          @server.add_plugin(Plugin.new)

          @node.put('1234567890')
        end

        def teardown
          FileUtils.remove_entry @temp_dir
        end

        def test_update_range
          data.each do |v|
            (header_value, http_status, end_result, content_length) = v
            content_length = 4 unless content_length

            # RUBY: restore file
            @node.put('1234567890')

            headers = {
              'Content-Type' => 'application/x-sabredav-partialupdate',
              'X-Update-Range' => header_value
            }

            if content_length > 0
              headers['Content-Length'] = content_length.to_s
            end

            request = Http::Request.new('PATCH', '/foobar.txt', headers, '----')

            request.body = '----'
            @server.http_request = request
            @server.http_response = Http::ResponseMock.new
            @server.sapi = Http::SapiMock.new
            @server.exec

            assert_equal(http_status, @server.http_response.status, "Incorrect http status received: #{@server.http_response.body}")
            unless end_result.nil?
              assert_equal(end_result, ::File.read("#{@temp_dir}/foobar.txt"))
            end
          end
        end

        def data
          [
            # Problems
            ['foo',       400, nil],
            ['bytes=0-3', 411, nil, 0],
            ['bytes=4-1', 416, nil],

            ['bytes=0-3', 204, '----567890'],
            ['bytes=1-4', 204, '1----67890'],
            ['bytes=0-',  204, '----567890'],
            ['bytes=-4',  204, '123456----'],
            ['bytes=-2',  204, '12345678----'],
            ['bytes=2-',  204, '12----7890'],
            ['append',    204, '1234567890----']
          ]
        end
      end
    end
  end
end
