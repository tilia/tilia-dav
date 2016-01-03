require 'test_helper'

module Tilia
  module CalDav
    # This unittest is created to check if queries for time-range include the start timestamp or not
    class GetEventsByTimerangeTest < DavServerTest
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
CREATED:20120313T142342Z
UID:171EBEFC-C951-499D-B234-7BA7D677B45D
DTEND;TZID=Europe/Berlin:20120227T010000
TRANSP:OPAQUE
SUMMARY:Monday 0h
DTSTART;TZID=Europe/Berlin:20120227T000000
DTSTAMP:20120313T142416Z
SEQUENCE:4
END:VEVENT
END:VCALENDAR
VCF
            }
          }
        }
        super
      end

      def test_query_timerange
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/calendar1',
          'Content-Type' => 'application/xml',
          'Depth'        => '1'
        )

        request.body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
    <D:prop>
        <C:calendar-data>
            <C:expand start="20120226T220000Z" end="20120228T225959Z"/>
        </C:calendar-data>
        <D:getetag/>
    </D:prop>
    <C:filter>
        <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VEVENT">
                <C:time-range start="20120226T220000Z" end="20120228T225959Z"/>
            </C:comp-filter>
        </C:comp-filter>
    </C:filter>
</C:calendar-query>
XML

        response = request(request)

        assert(response.body.index('BEGIN:VCALENDAR'))
      end
    end
  end
end
