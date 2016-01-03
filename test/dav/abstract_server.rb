require 'fileutils'

module Tilia
  module Dav
    class AbstractServer < Minitest::Test
      # @var Sabre\HTTP\ResponseMock
      attr_accessor :response
      attr_accessor :request
      # @var Sabre\DAV\Server
      attr_accessor :server
      attr_accessor :temp_dir

      def setup
        @temp_dir = Dir.mktmpdir

        @response = Http::ResponseMock.new
        @server = Server.new(TestUtil.mock_rack_env, root_node)
        @server.sapi = Http::SapiMock.new
        @server.http_response = @response
        @server.debug_exceptions = true

        ::File.open("#{@temp_dir}/test.txt", 'w') { |f| f.write 'Test contents' }
        Dir.mkdir("#{@temp_dir}/dir")
        ::File.open("#{@temp_dir}/dir/child.txt", 'w') { |f| f.write 'Child contents' }
      end

      def teardown
        FileUtils.remove_entry @temp_dir
      end

      def root_node
        Fs::Directory.new(@temp_dir)
      end
    end
  end
end
