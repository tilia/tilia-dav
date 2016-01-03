require 'test_helper'

module Tilia
  module CalDav
    class CalendarHomeSubscriptionsTest < Minitest::Test
      def setup
        props = {
          '{DAV:}displayname' => 'baz',
          '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/test.ics')
        }
        principal = {
          'uri' => 'principals/user1'
        }
        @backend = Backend::MockSubscriptionSupport.new([], [])
        @backend.create_subscription('principals/user1', 'uri', props)
        @instance = CalendarHome.new(@backend, principal)
      end

      def test_simple
        assert_equal('user1', @instance.name)
      end

      def test_get_children
        children = @instance.children
        assert_equal(1, children.size)

        found = false
        children.each do |child|
          found = true if child.is_a?(Subscriptions::Subscription)
        end

        assert(found, 'There were no subscription nodes in the calendar home')
      end

      def test_create_subscription
        rt = ['{DAV:}collection', '{http://calendarserver.org/ns/}subscribed']

        props = {
          '{DAV:}displayname' => 'baz',
          '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/test2.ics')
        }
        @instance.create_extended_collection('sub2', Dav::MkCol.new(rt, props))

        children = @instance.children
        assert_equal(2, children.size)
      end

      def test_no_subscription_support
        principal = {
          'uri' => 'principals/user1'
        }
        backend = Backend::Mock.new([], [])
        u_c = CalendarHome.new(backend, principal)

        rt = ['{DAV:}collection', '{http://calendarserver.org/ns/}subscribed']

        props = {
          '{DAV:}displayname' => 'baz',
          '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/test2.ics')
        }
        assert_raises(Dav::Exception::InvalidResourceType) do
          u_c.create_extended_collection('sub2', Dav::MkCol.new(rt, props))
        end
      end
    end
  end
end
