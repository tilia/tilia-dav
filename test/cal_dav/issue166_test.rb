require 'test_helper'

module Tilia
  module CalDav
    class Issue166Test < Minitest::Test
      def test_flaw
        input = <<HI
BEGIN:VCALENDAR
PRODID:-//Mozilla.org/NONSGML Mozilla Calendar V1.1//EN
VERSION:2.0
BEGIN:VTIMEZONE
TZID:Asia/Pyongyang
X-LIC-LOCATION:Asia/Pyongyang
BEGIN:STANDARD
TZOFFSETFROM:+0900
TZOFFSETTO:+0900
TZNAME:KST
DTSTART:19700101T000000
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
CREATED:20111118T010857Z
LAST-MODIFIED:20111118T010937Z
DTSTAMP:20111118T010937Z
UID:a03245b3-9947-9a48-a088-863c74e0fdd8
SUMMARY:New Event
RRULE:FREQ=YEARLY
DTSTART;TZID=Asia/Pyongyang:19960102T111500
DTEND;TZID=Asia/Pyongyang:19960102T121500
END:VEVENT
END:VCALENDAR
HI

        validator = CalendarQueryValidator.new

        filters = {
          'name' => 'VCALENDAR',
          'comp-filters' => [
            {
              'name' => 'VEVENT',
              'comp-filters' => [],
              'prop-filters' => [],
              'is-not-defined' => false,
              'time-range' => {
                'start' => Time.zone.parse('2011-12-01'),
                'end'   => Time.zone.parse('2012-02-01')
              }
            }
          ],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => nil
        }
        input = VObject::Reader.read(input)
        assert(validator.validate(input, filters))
      end
    end
  end
end
