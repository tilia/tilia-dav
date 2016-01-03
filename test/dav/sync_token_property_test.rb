module Tilia
  module Dav
    class SyncTokenPropertyTest < DavServerTest
      # The assumption in these tests is that a PROPFIND is going on, and to
      # fetch the sync-token, the event handler is just able to use the existing
      # result.
      def test_already_there1
        data.each do |v|
          (name, value) = v

          prop_find = PropFind.new(
            'foo',
            [
              '{http://calendarserver.org/ns/}getctag',
              name
            ]
          )

          prop_find.set(name, value)
          core_plugin = CorePlugin.new
          core_plugin.prop_find_late(prop_find, SimpleCollection.new('hi'))

          assert_equal('hello', prop_find.get('{http://calendarserver.org/ns/}getctag'))
        end
      end

      # In these test-cases, the plugin is forced to do a local propfind to
      # fetch the items.
      def test_refetch
        data.each do |v|
          (name, value) = v

          @server.tree = Tree.new(
            SimpleCollection.new(
              'root',
              [
                Mock::PropertiesCollection.new(
                  'foo',
                  [],
                  name => value
                )
              ]
            )
          )
          prop_find = PropFind.new(
            'foo',
            [
              '{http://calendarserver.org/ns/}getctag',
              name
            ]
          )

          core_plugin = @server.plugin('core')
          core_plugin.prop_find_late(prop_find, SimpleCollection.new('hi'))

          assert_equal('hello', prop_find.get('{http://calendarserver.org/ns/}getctag'))
        end
      end

      def test_no_data
        @server.tree = Tree.new(
          SimpleCollection.new(
            'root',
            [
              Mock::PropertiesCollection.new(
                'foo',
                [],
                {}
              )
            ]
          )
        )

        prop_find = PropFind.new(
          'foo',
          [
            '{http://calendarserver.org/ns/}getctag'
          ]
        )

        core_plugin = @server.plugin('core')
        core_plugin.prop_find_late(prop_find, SimpleCollection.new('hi'))

        assert_nil(prop_find.get('{http://calendarserver.org/ns/}getctag'))
      end

      def data
        [
          [
            '{http://sabredav.org/ns}sync-token',
            'hello'
          ],
          [
            '{DAV:}sync-token',
            'hello'
          ],
          [
            '{DAV:}sync-token',
            Xml::Property::Href.new(Sync::Plugin::SYNCTOKEN_PREFIX + 'hello', false)
          ]
        ]
      end
    end
  end
end
