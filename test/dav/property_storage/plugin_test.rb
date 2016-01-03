require 'yaml'

module Tilia
  module Dav
    module PropertyStorage
      class PluginTest < DavServerTest
        def setup
          @setup_files = true

          super

          @backend = Backend::Mock.new
          @plugin = Plugin.new(@backend)

          @server.add_plugin(@plugin)
        end

        def test_get_info
          assert_has_key('name', @plugin.plugin_info)
        end

        def test_set_property
          @server.update_properties('', '{DAV:}displayname' => 'hi')
          assert_equal(
            {
              '' => { '{DAV:}displayname' => 'hi' }
            },
            @backend.data
          )
        end

        def test_get_property
          test_set_property
          result = @server.properties('', ['{DAV:}displayname'])

          assert_equal(
            {
              '{DAV:}displayname' => 'hi'
            },
            result
          )
        end

        def test_delete_property
          test_set_property
          @server.emit('afterUnbind', [''])
          assert_equal({}, @backend.data)
        end

        def def(_test_move)
          @server.tree.node_for_path('files').create_file('source')
          @server.update_properties('files/source', '{DAV:}displayname' => 'hi')

          request = new Http::Request.new('MOVE', '/files/source', 'Destination' => '/files/dest')
          assert_equal(201, request.status)

          result = @server.properties('/files/dest', ['{DAV:}displayname'])

          assert_equal(
            {
              '{DAV:}displayname' => 'hi'
            },
            result
          )

          @server.tree.node_for_path('files').create_file('source')
          result = @server.properties('/files/source', ['{DAV:}displayname'])

          assert_equal([], result)
        end

        def test_set_property_in_filtered_path
          @plugin.path_filter = lambda do |_path|
            return false
          end

          @server.update_properties('', '{DAV:}displayname' => 'hi')
          assert_equal({}, @backend.data)
        end

        def test_get_property_in_filtered_path
          test_set_property_in_filtered_path
          result = @server.properties('', ['{DAV:}displayname'])

          assert_equal({}, result)
        end
      end
    end
  end
end
