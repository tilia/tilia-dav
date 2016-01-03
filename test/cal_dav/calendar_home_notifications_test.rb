require 'test_helper'

module Tilia
  module CalDav
    class CalendarHomeNotificationsTest < Minitest::Test
      def test_get_children_no_support
        backend = Backend::Mock.new
        calendar_home = CalendarHome.new(backend, 'uri' => 'principals/user')

        assert_equal(
          [],
          calendar_home.children
        )
      end

      # @expectedException \Sabre\DAV\Exception\NotFound
      def test_get_child_no_support
        backend = Backend::Mock.new
        calendar_home = CalendarHome.new(backend, 'uri' => 'principals/user')
        assert_raises(Dav::Exception::NotFound) do
          calendar_home.child('notifications')
        end
      end

      def test_get_children
        backend = Backend::MockSharing.new
        calendar_home = CalendarHome.new(backend, 'uri' => 'principals/user')

        result = calendar_home.children
        assert_equal('notifications', result[0].name)
      end

      def test_get_child
        backend = Backend::MockSharing.new
        calendar_home = CalendarHome.new(backend, 'uri' => 'principals/user')
        result = calendar_home.child('notifications')
        assert_equal('notifications', result.name)
      end
    end
  end
end
