require 'test_helper'

module Tilia
  module Dav
    module Locks
      class MSWordTest < Minitest::Test
        def setup
          @temp_dir = Dir.mktmpdir
        end

        def teardown
          FileUtils.remove_entry @temp_dir
        end

        def test_lock_etc
          Dir.mkdir("#{@temp_dir}/mstest")
          tree = Fs::Directory.new("#{@temp_dir}/mstest")

          server = ServerMock.new(tree)
          server.debug_exceptions = true
          locks_backend = Backend::File.new("#{@temp_dir}/locksdb")
          locks_plugin = Plugin.new(locks_backend)
          server.add_plugin(locks_plugin)

          response1 = Http::ResponseMock.new

          server.http_request = lock_request
          server.http_response = response1
          server.sapi = Http::SapiMock.new
          server.exec

          assert_equal(201, server.http_response.status, "Full response body: #{response1.body_as_string}")
          assert(server.http_response.header('Lock-Token'))
          lock_token = server.http_response.header('Lock-Token')

          # sleep(10)

          response2 = Http::ResponseMock.new

          server.http_request = lock_request2
          server.http_response = response2
          server.exec

          assert_equal(201, server.http_response.status)
          assert(server.http_response.header('Lock-Token'))

          # sleep(10)

          response3 = Http::ResponseMock.new
          server.http_request = get_put_request(lock_token)
          server.http_response = response3
          server.exec

          assert_equal(204, server.http_response.status)
        end

        def lock_request
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'    => 'LOCK',
            'HTTP_CONTENT_TYPE' => 'application/xml',
            'HTTP_TIMEOUT'      => 'Second-3600',
            'REQUEST_PATH'      => '/Nouveau%20Microsoft%20Office%20Excel%20Worksheet.xlsx'
          )

          request.body = <<XML
<D:lockinfo xmlns:D="DAV:">
  <D:lockscope>
    <D:exclusive />
  </D:lockscope>
  <D:locktype>
    <D:write />
  </D:locktype>
  <D:owner>
    <D:href>PC-Vista\User</D:href>
  </D:owner>
</D:lockinfo>
XML

          request
        end

        def lock_request2
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'    => 'LOCK',
            'HTTP_CONTENT_TYPE' => 'application/xml',
            'HTTP_TIMEOUT'      => 'Second-3600',
            'REQUEST_PATH'      => '/~$Nouveau%20Microsoft%20Office%20Excel%20Worksheet.xlsx'
          )

          request.body = <<XML
<D:lockinfo xmlns:D="DAV:">
  <D:lockscope>
    <D:exclusive />
  </D:lockscope>
  <D:locktype>
    <D:write />
  </D:locktype>
  <D:owner>
    <D:href>PC-Vista\User</D:href>
  </D:owner>
</D:lockinfo>
XML

          request
        end

        def get_put_request(lock_token)
          request = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'    => 'PUT',
            'REQUEST_PATH'      => '/Nouveau%20Microsoft%20Office%20Excel%20Worksheet.xlsx',
            'HTTP_IF'           => "If: (#{lock_token})"
          )
          request.body = 'FAKE BODY'
          request
        end
      end
    end
  end
end
