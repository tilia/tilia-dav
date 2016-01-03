require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class PluginBasicTest < DavServerTest
        def setup
          @setup_cal_dav = true
          @setup_cal_dav_scheduling = true

          super
        end

        def test_simple
          plugin = Plugin.new
          assert_equal(
            'caldav-schedule',
            plugin.plugin_info['name']
          )
        end

        def test_options
          plugin = Plugin.new
          expected = [
            'calendar-auto-schedule',
            'calendar-availability'
          ]
          assert_equal(expected, plugin.features)
        end

        def test_get_http_methods
          assert_equal([], @caldav_schedule_plugin.http_methods('notfound'))
          assert_equal([], @caldav_schedule_plugin.http_methods('calendars/user1'))
          assert_equal(['POST'], @caldav_schedule_plugin.http_methods('calendars/user1/outbox'))
        end
      end
    end
  end
end
