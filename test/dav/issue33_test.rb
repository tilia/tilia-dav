require 'test_helper'

module Tilia
  module Dav
    class Issue33Test < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
      end

      def teardown
        FileUtils.remove_entry @temp_dir
      end

      def test_copy_move_info
        bar = SimpleCollection.new('bar')
        root = SimpleCollection.new('webdav', [bar])

        server = ServerMock.new(root)
        server.base_uri = '/webdav/'

        server_vars = {
          'REQUEST_PATH'     => '/webdav/bar',
          'HTTP_DESTINATION' => 'http://dev2.tribalos.com/webdav/%C3%A0fo%C3%B3',
          'HTTP_OVERWRITE'   => 'F'
        }

        request = Http::Sapi.create_from_server_array(server_vars)

        server.http_request = request

        info = server.copy_and_move_info(request)

        assert_equal('%C3%A0fo%C3%B3', URI.encode(info['destination']))
        refute(info['destinationExists'])
        refute(info['destinationNode'])
      end

      def test_tree_move
        dir = Fs::Directory.new(@temp_dir)

        dir.create_directory('bar')

        tree = Tree.new(dir)
        tree.move('bar', URI.decode('%C3%A0fo%C3%B3'))

        node = tree.node_for_path(URI.decode('%C3%A0fo%C3%B3'))
        assert_equal(URI.decode('%C3%A0fo%C3%B3'), node.name)
      end

      def test_dir_name
        dirname1 = 'bar'
        dirname2 = URI.encode('%C3%A0fo%C3%B3')

        assert(::File.dirname(dirname1) == ::File.dirname(dirname2))
      end

      def test_everything
        # Request object
        server_vars = {
          'REQUEST_METHOD'   => 'MOVE',
          'REQUEST_PATH'     => '/webdav/bar',
          'HTTP_DESTINATION' => 'http://dev2.tribalos.com/webdav/%C3%A0fo%C3%B3',
          'HTTP_OVERWRITE'   => 'F'
        }

        request = Http::Sapi.create_from_server_array(server_vars)
        request.body = ''

        response = Http::ResponseMock.new

        # Server setup
        dir = Fs::Directory.new(@temp_dir)

        dir.create_directory('bar')

        tree = Tree.new(dir)

        server = ServerMock.new(tree)
        server.base_uri = '/webdav/'

        server.http_request = request
        server.http_response = response
        server.sapi = Http::SapiMock.new
        server.exec

        assert(::File.exist?("#{@temp_dir}/#{URI.decode('%C3%A0fo%C3%B3')}"))
      end
    end
  end
end
