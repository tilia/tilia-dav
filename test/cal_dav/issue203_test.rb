require 'test_helper'

module Tilia
  module CalDav
    # This unittest is created to find out why an overwritten DAILY event has wrong DTSTART, DTEND, SUMMARY and RECURRENCEID
    class Issue203Test < DavServerTest
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
RRULE:FREQ=DAILY;COUNT=2;INTERVAL=1
SUMMARY:original summary
TRANSP:OPAQUE
END:VEVENT
BEGIN:VEVENT
UID:20120330T155305CEST-6585fBUVgV
DTSTAMP:20120330T135352Z
DESCRIPTION:
DTSTART;TZID=Europe/Berlin:20120328T155200
DTEND;TZID=Europe/Berlin:20120328T165200
RECURRENCE-ID;TZID=Europe/Berlin:20120327T155200
SEQUENCE:1
SUMMARY:overwritten summary
TRANSP:OPAQUE
END:VEVENT
END:VCALENDAR
VCF
            }
          }
        }
        super
      end

      def test_issue203
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD'    => 'REPORT',
          'HTTP_CONTENT_TYPE' => 'application/xml',
          'REQUEST_PATH'      => '/calendars/user1/calendar1',
          'HTTP_DEPTH'        => '1'
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
                <C:time-range start="20120325T220000Z" end="20120401T215959Z"/>
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

        assert_equal(2, v_object['VEVENT'].size)

        expected_events = [
          {
            'DTSTART' => '20120326T135200Z',
            'DTEND'   => '20120326T145200Z',
            'SUMMARY' => 'original summary'
          },
          {
            'DTSTART'       => '20120328T135200Z',
            'DTEND'         => '20120328T145200Z',
            'SUMMARY'       => 'overwritten summary',
            'RECURRENCE-ID' => '20120327T135200Z'
          }
        ]

        # try to match agains expected_events array
        expected_events.each do |expected_event|
          matching = false

          v_object['VEVENT'].each do |vevent|
            # @var vevent Sabre\VObject\Component\VEvent
            skip = false
            vevent.children.each do |child|
              # @var child Sabre\VObject\Property
              next unless expected_event.key?(child.name)
              if expected_event[child.name] != child.value
                skip = true
                break
                              end
            end
            next if skip

            matching = true
            break
          end

          assert(matching, "Did not find the following event in the response: #{expected_event.inspect}")
        end
      end
    end
  end
end
