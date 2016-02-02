require 'test_helper'

module Tilia
  module CalDav
    # This unittests is created to find out why certain events show up twice.
    #
    # Hopefully, by the time I'm done with this, I've both found the problem, and
    # fixed it :)
    class ExpandEventsDoubleEventsTest < DavServerTest
      def setup
        @setup_cal_dav = true
        @caldav_calendars = [
          {
            'id' => 1,
            'name' => 'Calendar',
            'principaluri' => 'principals/user1',
            'uri' => 'calendar1'
          }
        ]
        @caldav_calendar_objects = {
          1 => {
            'event.ics' => {
              'calendardata' => <<VCF
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:foobar
DTEND;TZID=Europe/Berlin:20120207T191500
RRULE:FREQ=DAILY;INTERVAL=1;COUNT=3
SUMMARY:RecurringEvents 3 times
DTSTART;TZID=Europe/Berlin:20120207T181500
END:VEVENT
BEGIN:VEVENT
CREATED:20120207T111900Z
UID:foobar
DTEND;TZID=Europe/Berlin:20120208T191500
SUMMARY:RecurringEvents 3 times OVERWRITTEN
DTSTART;TZID=Europe/Berlin:20120208T181500
RECURRENCE-ID;TZID=Europe/Berlin:20120208T181500
END:VEVENT
END:VCALENDAR
VCF
            }
          }
        }
        super
      end

      def test_expand
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'HTTP_CONTENT_TYPE' => 'application/xml',
          'PATH_INFO'    => '/calendars/user1/calendar1',
          'HTTP_DEPTH' => '1'
        )

        request.body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
    <D:prop>
        <C:calendar-data>
            <C:expand start="20120205T230000Z" end="20120212T225959Z"/>
        </C:calendar-data>
        <D:getetag/>
    </D:prop>
    <C:filter>
        <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VEVENT">
                <C:time-range start="20120205T230000Z" end="20120212T225959Z"/>
            </C:comp-filter>
        </C:comp-filter>
    </C:filter>
</C:calendar-query>
XML

        response = request(request)

        # Everts super awesome xml parser.
        start = response.body.index('BEGIN:VCALENDAR')
        length = response.body.index('END:VCALENDAR') - start + 13
        body = response.body[start, length]
        body = body.gsub('&#13;', '')

        v_object = VObject::Reader.read(body)

        # We only expect 3 events
        assert_equal(3, v_object['VEVENT'].size, "We got #{v_object['VEVENT'].size} events instead of 3. Output: #{body}")

        # TZID should be gone
        refute(v_object['VEVENT']['DTSTART'].key?('TZID'))
      end
    end
  end
end
