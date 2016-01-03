require 'test_helper'

module Tilia
  module CalDav
    module Subscriptions
      class PluginTest < Minitest::Test
        def test_init
          server = Dav::ServerMock.new
          plugin = Plugin.new

          server.add_plugin(plugin)

          assert_equal(
            '{http://calendarserver.org/ns/}subscribed',
            server.resource_type_mapping[ISubscription]
          )
          assert_equal(
            Dav::Xml::Property::Href,
            server.xml.element_map['{http://calendarserver.org/ns/}source']
          )

          assert_equal(
            ['calendarserver-subscribed'],
            plugin.features
          )

          assert_equal(
            'subscriptions',
            plugin.plugin_info['name']
          )
        end

        def test_prop_find
          prop_name = '{http://calendarserver.org/ns/}subscribed-strip-alarms'
          prop_find = Dav::PropFind.new('foo', [prop_name])
          prop_find.set(prop_name, nil, 200)

          plugin = Plugin.new
          plugin.prop_find(prop_find, Dav::SimpleCollection.new('hi'))

          refute(prop_find.get(prop_name).nil?)
        end
      end
    end
  end
end
