require 'test_helper'

module Tilia
  module Dav
    class BasicNodeTest < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
      end

      def teardown
        FileUtils.remove_entry @temp_dir
      end

      # This test makes sure that a path like /foo cannot be copied into a path
      # like /foo/bar/
      def test_copy_into_sub_path
        dir = Fs::Directory.new(@temp_dir)
        server = ServerMock.new(dir)

        dir.create_directory('foo')

        request = Http::Request.new(
          'COPY',
          '/foo',
          'Destination' => '/foo/bar'
        )
        response = Http::ResponseMock.new

        assert_raises(Exception::Conflict) { server.invoke_method(request, response) }
      end
    end
  end
end
