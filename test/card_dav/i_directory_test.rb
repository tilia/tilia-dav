require 'test_helper'

module Tilia
  module CardDav
    class IDirectoryTest < Minitest::Test
      def test_resource_type
        tree = [DirectoryMock.new('directory')]

        server = Dav::ServerMock.new(tree)
        plugin = Plugin.new
        server.add_plugin(plugin)

        props = server.properties('directory', ['{DAV:}resourcetype'])
        assert(props['{DAV:}resourcetype'].is("{#{Plugin::NS_CARDDAV}}directory"))
      end
    end

    class DirectoryMock < Dav::SimpleCollection
      include IDirectory
    end
  end
end
