require 'test_helper'

module Tilia
  module CalDav
    # This unittest is created to check if expand works correctly with
    # floating times (using calendar-timezone information).
    class ExpandEventsFloatingTimeTest < DavServerTest
      def setup
        @setup_cal_dav = true
        @setup_cal_davics_export = true
        @caldav_calendars = [
          {
            'id'                                               => 1,
            'name'                                             => 'Calendar',
            'principaluri'                                     => 'principals/user1',
            'uri'                                              => 'calendar1',
            '{urn:ietf:params:xml:ns:caldav}calendar-timezone' => <<VCF
BEGIN:VCALENDAR
VERSION:2.0
CALSCALE:GREGORIAN
BEGIN:VTIMEZONE
TZID:Europe/Berlin
BEGIN:DAYLIGHT
TZOFFSETFROM:+0100
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU
DTSTART:19810329T020000
TZNAME:GMT+2
TZOFFSETTO:+0200
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+0200
RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU
DTSTART:19961027T030000
TZNAME:GMT+1
TZOFFSETTO:+0100
END:STANDARD
END:VTIMEZONE
END:VCALENDAR
VCF
          }
        ]

        @caldav_calendar_objects = {
          1 => {
            'event.ics' => {
              'calendardata' => <<VCF
BEGIN:VCALENDAR
VERSION:2.0
CALSCALE:GREGORIAN
BEGIN:VEVENT
CREATED:20140701T143658Z
UID:dba46fe8-1631-4d98-a575-97963c364dfe
DTEND:20141108T073000
TRANSP:OPAQUE
SUMMARY:Floating Time event, starting 05:30am Europe/Berlin
DTSTART:20141108T053000
DTSTAMP:20140701T143706Z
SEQUENCE:1
END:VEVENT
END:VCALENDAR
VCF
            }
          }
        }

        super
      end

      def test_expand_calendar_query
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/calendar1',
          'Depth'        => 1,
          'Content-Type' => 'application/xml'
        )

        request.body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
    <D:prop>
        <C:calendar-data>
            <C:expand start="20141107T230000Z" end="20141108T225959Z"/>
        </C:calendar-data>
        <D:getetag/>
    </D:prop>
    <C:filter>
        <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VEVENT">
                <C:time-range start="20141107T230000Z" end="20141108T225959Z"/>
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

        # check if DTSTARTs and DTENDs are correct
        v_object['VEVENT'].each do |vevent|
          # @var vevent Sabre\VObject\Component\VEvent
          vevent.children.each do |child|
            # @var child Sabre\VObject\Property
            if child.name == 'DTSTART'
              # DTSTART should be the UTC equivalent of given floating time
              assert_equal('20141108T043000Z', child.value)
            elsif child.name == 'DTEND'
              # DTEND should be the UTC equivalent of given floating time
              assert_equal('20141108T063000Z', child.value)
            end
          end
        end
      end

      def test_expand_multi_get
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/calendar1',
          'Depth'        => 1,
          'Content-Type' => 'application/xml'
        )

        request.body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
    <D:prop>
        <C:calendar-data>
            <C:expand start="20141107T230000Z" end="20141108T225959Z"/>
        </C:calendar-data>
        <D:getetag/>
    </D:prop>
    <D:href>/calendars/user1/calendar1/event.ics</D:href>
</C:calendar-multiget>
XML

        response = request(request)

        assert_equal(207, response.status)

        # Everts super awesome xml parser.
        start = response.body.index('BEGIN:VCALENDAR')
        length = response.body.index('END:VCALENDAR') - start + 13
        body = response.body[start, length]
        body = body.gsub('&#13;', '')

        v_object = VObject::Reader.read(body)

        # check if DTSTARTs and DTENDs are correct
        v_object['VEVENT'].each do |vevent|
          # @var vevent Sabre\VObject\Component\VEvent
          vevent.children.each do |child|
            # @var child Sabre\VObject\Property
            if child.name == 'DTSTART'
              # DTSTART should be the UTC equivalent of given floating time
              assert_equal('20141108T043000Z', child.value)
            elsif child.name == 'DTEND'
              # DTEND should be the UTC equivalent of given floating time
              assert_equal('20141108T063000Z', child.value)
            end
          end
        end
      end

      def test_expand_export
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD'    => 'GET',
          'HTTP_CONTENT_TYPE' => 'application/xml',
          'PATH_INFO'         => '/calendars/user1/calendar1',
          'HTTP_DEPTH'        => '1',
          'QUERY_STRING'      => 'export&start=1&end=2000000000&expand=1'
        )

        response = request(request)

        assert_equal(200, response.status)

        # Everts super awesome xml parser.
        start = response.body.index('BEGIN:VCALENDAR')
        length = response.body.index('END:VCALENDAR') - start + 13
        body = response.body[start, length]
        body = body.gsub('&#13;', '')

        v_object = VObject::Reader.read(body)

        assert(v_object['VEVENT'])

        # check if DTSTARTs and DTENDs are correct
        v_object['VEVENT'].each do |vevent|
          # @var vevent Sabre\VObject\Component\VEvent
          vevent.children.each do |child|
            # @var child Sabre\VObject\Property
            if child.name == 'DTSTART'
              # DTSTART should be the UTC equivalent of given floating time
              assert_equal('20141108T043000Z', child.value)
            elsif child.name == 'DTEND'
              # DTEND should be the UTC equivalent of given floating time
              assert_equal('20141108T063000Z', child.value)
            end
          end
        end
      end
    end
  end
end
