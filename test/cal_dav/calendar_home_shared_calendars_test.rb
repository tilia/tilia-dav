require 'test_helper'

module Tilia
  module CalDav
    class CalendarHomeSharedCalendarsTest < Minitest::Test
      def setup
        calendars = [
          {
            'id' => 1,
            'principaluri' => 'principals/user1'
          },
          {
            'id' => 2,
            '{http://calendarserver.org/ns/}shared-url' => 'calendars/owner/cal1',
            '{http://sabredav.org/ns}owner-principal' => 'principal/owner',
            '{http://sabredav.org/ns}read-only' => false,
            'principaluri' => 'principals/user1'
          }
        ]

        @backend = Backend::MockSharing.new(
          calendars,
          [],
          {}
        )

        @instance = CalendarHome.new(
          @backend,
          'uri' => 'principals/user1'
        )
      end

      def test_simple
        assert_equal('user1', @instance.name)
      end

      def test_get_children
        children = @instance.children
        assert_equal(3, children.size)

        # Testing if we got all the objects back.
        has_shareable = false
        has_shared = false
        has_outbox = false
        has_notifications = false

        children.each do |child|
          has_shareable = true if child.is_a?(IShareableCalendar)
          has_shared = true if child.is_a?(ISharedCalendar)
          has_notifications = true if child.is_a?(Notifications::ICollection)
        end

        fail('Missing node!') unless has_shareable
        fail('Missing node!') unless has_shared
        fail('Missing node!') unless has_notifications
      end

      def test_share_reply
        result = @instance.share_reply('uri', SharingPlugin::STATUS_DECLINED, 'curi', '1')
        assert_nil(result)
      end
    end
  end
end
