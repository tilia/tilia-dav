require 'test_helper'

module Tilia
  module CalDav
    # This unittest is created to check if a VALARM TRIGGER of PT0S is supported
    class Issue205Test < DavServerTest
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
UID:20120330T155305CEST-6585fBUVgV
DTSTAMP:20120330T135305Z
DTSTART;TZID=Europe/Berlin:20120326T155200
DTEND;TZID=Europe/Berlin:20120326T165200
SUMMARY:original summary
TRANSP:OPAQUE
BEGIN:VALARM
ACTION:AUDIO
ATTACH;VALUE=URI:Basso
TRIGGER:PT0S
END:VALARM
END:VEVENT
END:VCALENDAR
VCF
            }
          }
        }
        super
      end

      def test_issue205
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
            <C:expand start="20120325T220000Z" end="20120401T215959Z"/>
        </C:calendar-data>
        <D:getetag/>
    </D:prop>
    <C:filter>
        <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VEVENT">
                <C:comp-filter name="VALARM">
                    <C:time-range start="20120325T220000Z" end="20120401T215959Z"/>
                </C:comp-filter>
            </C:comp-filter>
        </C:comp-filter>
    </C:filter>
</C:calendar-query>
XML

        response = request(request)

        refute(response.body.index('<s:exception>'), "Exception occurred: #{response.body}")

        # Everts super awesome xml parser.
        start = response.body.index('BEGIN:VCALENDAR')
        length = response.body.index('END:VCALENDAR') - start + 13
        body = response.body[start, length]
        body = body.gsub('&#13;', '')

        v_object = VObject::Reader.read(body)

        assert_equal(1, v_object['VEVENT'].size)
      end
    end
  end
end
