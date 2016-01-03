require 'test_helper'

module Tilia
  module CalDav
    module Subscriptions
      class CreateSubscriptionTest < DavServerTest
        def setup
          @setup_cal_dav = true
          @setup_cal_dav_subscriptions = true
          super
        end

        # OS X 10.7 - 10.9.1
        def test_mkcol
          body = <<XML
<A:mkcol xmlns:A="DAV:">
    <A:set>
        <A:prop>
            <B:subscribed-strip-attachments xmlns:B="http://calendarserver.org/ns/" />
            <B:subscribed-strip-todos xmlns:B="http://calendarserver.org/ns/" />
            <A:resourcetype>
                <A:collection />
                <B:subscribed xmlns:B="http://calendarserver.org/ns/" />
            </A:resourcetype>
            <E:calendar-color xmlns:E="http://apple.com/ns/ical/">#1C4587FF</E:calendar-color>
            <A:displayname>Jewish holidays</A:displayname>
            <C:calendar-description xmlns:C="urn:ietf:params:xml:ns:caldav">Foo</C:calendar-description>
            <E:calendar-order xmlns:E="http://apple.com/ns/ical/">19</E:calendar-order>
            <B:source xmlns:B="http://calendarserver.org/ns/">
                <A:href>webcal://www.example.org/</A:href>
            </B:source>
            <E:refreshrate xmlns:E="http://apple.com/ns/ical/">P1W</E:refreshrate>
            <B:subscribed-strip-alarms xmlns:B="http://calendarserver.org/ns/" />
        </A:prop>
    </A:set>
</A:mkcol>
XML

          headers = {
            'Content-Type' => 'application/xml'
          }
          request = Http::Request.new('MKCOL', '/calendars/user1/subscription1', headers, body)

          response = request(request)
          assert_equal(201, response.status)
          subscriptions = @caldav_backend.subscriptions_for_user('principals/user1')
          assert_subscription(subscriptions[0])
        end

        # OS X 10.9.2 and up
        def test_mkcalendar
          body = <<XML
<B:mkcalendar xmlns:B="urn:ietf:params:xml:ns:caldav">
    <A:set xmlns:A="DAV:">
        <A:prop>
            <B:supported-calendar-component-set>
                <B:comp name="VEVENT" />
            </B:supported-calendar-component-set>
            <C:subscribed-strip-alarms xmlns:C="http://calendarserver.org/ns/" />
            <C:subscribed-strip-attachments xmlns:C="http://calendarserver.org/ns/" />
            <A:resourcetype>
                <A:collection />
                <C:subscribed xmlns:C="http://calendarserver.org/ns/" />
            </A:resourcetype>
            <D:refreshrate xmlns:D="http://apple.com/ns/ical/">P1W</D:refreshrate>
            <C:source xmlns:C="http://calendarserver.org/ns/">
                <A:href>webcal://www.example.org/</A:href>
            </C:source>
            <D:calendar-color xmlns:D="http://apple.com/ns/ical/">#1C4587FF</D:calendar-color>
            <D:calendar-order xmlns:D="http://apple.com/ns/ical/">19</D:calendar-order>
            <B:calendar-description>Foo</B:calendar-description>
            <C:subscribed-strip-todos xmlns:C="http://calendarserver.org/ns/" />
            <A:displayname>Jewish holidays</A:displayname>
        </A:prop>
    </A:set>
</B:mkcalendar>
XML

          headers = {
            'Content-Type' => 'application/xml'
          }
          request = Http::Request.new('MKCALENDAR', '/calendars/user1/subscription1', headers, body)

          response = request(request)
          assert_equal(201, response.status)
          subscriptions = @caldav_backend.subscriptions_for_user('principals/user1')
          assert_subscription(subscriptions[0])

          # Also seeing if it works when calling this as a PROPFIND.
          assert_equal(
            {
              '{http://calendarserver.org/ns/}subscribed-strip-alarms' => ''
            },
            @server.properties('calendars/user1/subscription1', ['{http://calendarserver.org/ns/}subscribed-strip-alarms'])
          )
        end

        def assert_subscription(subscription)
          assert_equal(nil, subscription['{http://calendarserver.org/ns/}subscribed-strip-attachments'])
          assert_equal(nil, subscription['{http://calendarserver.org/ns/}subscribed-strip-todos'])
          assert_equal('#1C4587FF', subscription['{http://apple.com/ns/ical/}calendar-color'])
          assert_equal('Jewish holidays', subscription['{DAV:}displayname'])
          assert_equal('Foo', subscription['{urn:ietf:params:xml:ns:caldav}calendar-description'])
          assert_equal('19', subscription['{http://apple.com/ns/ical/}calendar-order'])
          assert_equal('webcal://www.example.org/', subscription['{http://calendarserver.org/ns/}source'].href)
          assert_equal('P1W', subscription['{http://apple.com/ns/ical/}refreshrate'])
          assert_equal('subscription1', subscription['uri'])
          assert_equal('principals/user1', subscription['principaluri'])
          assert_equal('webcal://www.example.org/', subscription['source'])
          assert_equal(['principals/user1', 1], subscription['id'])
        end
      end
    end
  end
end
