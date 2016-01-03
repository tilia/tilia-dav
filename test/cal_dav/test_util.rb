module Tilia
  module CalDav
    module DatabaseUtil
      def self.backend
        backend = Backend::Sequel.new(sqlite_db)
        backend
      end

      def self.sqlite_db
        db = Backend::SequelSqliteTest.sequel

        # Inserting events through a backend class.
        backend = Backend::Sequel.new(db)
        calendar_id = backend.create_calendar(
          'principals/user1',
          'UUID-123467',
          '{DAV:}displayname' => 'user1 calendar',
          '{urn:ietf:params:xml:ns:caldav}calendar-description' => 'Calendar description',
          '{http://apple.com/ns/ical/}calendar-order' => '1',
          '{http://apple.com/ns/ical/}calendar-color' => '#FF0000'
        )
        backend.create_calendar(
          'principals/user1',
          'UUID-123468',
          '{DAV:}displayname' => 'user1 calendar2',
          '{urn:ietf:params:xml:ns:caldav}calendar-description' => 'Calendar description',
          '{http://apple.com/ns/ical/}calendar-order' => '1',
          '{http://apple.com/ns/ical/}calendar-color' => '#FF0000'
        )
        backend.create_calendar_object(
          calendar_id,
          'UUID-2345',
          get_test_calendar_data
        )
        db
      end

      def self.get_test_calendar_data(type = 1)
        calendar_data = <<ICAL
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//iCal 4.0.1//EN
CALSCALE:GREGORIAN
BEGIN:VTIMEZONE
TZID:Asia/Seoul
BEGIN:DAYLIGHT
TZOFFSETFROM:+0900
RRULE:FREQ=YEARLY;UNTIL=19880507T150000Z;BYMONTH=5;BYDAY=2SU
DTSTART:19870510T000000
TZNAME:GMT+09:00
TZOFFSETTO:+1000
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:+1000
DTSTART:19881009T000000
TZNAME:GMT+09:00
TZOFFSETTO:+0900
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
CREATED:20100225T154229Z
UID:39A6B5ED-DD51-4AFE-A683-C35EE3749627
TRANSP:TRANSPARENT
SUMMARY:Something here
DTSTAMP:20100228T130202Z
ICAL

        case type
        when 1
          calendar_data += "DTSTART;TZID=Asia/Seoul:20100223T060000\nDTEND;TZID=Asia/Seoul:20100223T070000\n"
        when 2
          calendar_data += "DTSTART:20100223T060000\nDTEND:20100223T070000\n"
        when 3
          calendar_data += "DTSTART;VALUE=DATE:20100223\nDTEND;VALUE=DATE:20100223\n"
        when 4
          calendar_data += "DTSTART;TZID=Asia/Seoul:20100223T060000\nDURATION:PT1H\n"
        when 5
          calendar_data += "DTSTART;TZID=Asia/Seoul:20100223T060000\nDURATION:-P5D\n"
        when 6
          calendar_data += "DTSTART;VALUE=DATE:20100223\n"
        when 7
          calendar_data += "DTSTART;VALUE=DATETIME:20100223T060000\n"
        # No DTSTART, so intentionally broken
        when 'X'
          calendar_data += ''
        end

        calendar_data << <<ICAL
ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:lisa@example.com
SEQUENCE:2
END:VEVENT
END:VCALENDAR
ICAL

        calendar_data.chomp
      end

      def self.get_test_todo(type = 'due')
        case type
        when 'due'
          extra = 'DUE:20100104T000000Z'
        when 'due2'
          extra = 'DUE:20060104T000000Z'
        when 'due_date'
          extra = 'DUE;VALUE=DATE:20060104'
        when 'due_tz'
          extra = 'DUE;TZID=Asia/Seoul:20060104T000000Z'
        when 'due_dtstart'
          extra = "DTSTART:20050223T060000Z\nDUE:20060104T000000Z"
        when 'due_dtstart2'
          extra = "DTSTART:20090223T060000Z\nDUE:20100104T000000Z"
        when 'dtstart'
          extra = 'DTSTART:20100223T060000Z'
        when 'dtstart2'
          extra = 'DTSTART:20060223T060000Z'
        when 'dtstart_date'
          extra = 'DTSTART;VALUE=DATE:20100223'
        when 'dtstart_tz'
          extra = 'DTSTART;TZID=Asia/Seoul:20100223T060000Z'
        when 'dtstart_duration'
          extra = "DTSTART:20061023T060000Z\nDURATION:PT1H"
        when 'dtstart_duration2'
          extra = "DTSTART:20101023T060000Z\nDURATION:PT1H"
        when 'completed'
          extra = 'COMPLETED:20060601T000000Z'
        when 'completed2'
          extra = 'COMPLETED:20090601T000000Z'
        when 'created'
          extra = 'CREATED:20060601T000000Z'
        when 'created2'
          extra = 'CREATED:20090601T000000Z'
        when 'completedcreated'
          extra = "CREATED:20060601T000000Z\nCOMPLETED:20070101T000000Z"
        when 'completedcreated2'
          extra = "CREATED:20090601T000000Z\nCOMPLETED:20100101T000000Z"
        when 'notime'
          extra = 'X-FILLER:oh hello'
        else
          fail "Unknown type: #{type}"
        end

        todo = <<ICAL

BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example Corp.//CalDAV Client//EN
BEGIN:VTODO
DTSTAMP:20060205T235335Z
#{extra}
STATUS:NEEDS-ACTION
SUMMARY:Task #1
UID:DDDEEB7915FA61233B861457@example.com
BEGIN:VALARM
ACTION:AUDIO
TRIGGER;RELATED=START:-PT10M
END:VALARM
END:VTODO
END:VCALENDAR
ICAL
        todo.chomp
      end
    end
  end
end
