require 'test_helper'

module Tilia
  module CalDav
    class Issue172Test < Minitest::Test
      # DateTimeZone native name: America/Los_Angeles (GMT-8 in January)
      def test_built_in_timezone_name
        input = <<HI
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART;TZID=America/Los_Angeles:20120118T204500
DTEND;TZID=America/Los_Angeles:20120118T214500
END:VEVENT
END:VCALENDAR
HI

        la = ActiveSupport::TimeZone.new(-8)
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
                'start' => la.parse('2012-01-18 21:00:00'),
                'end'   => la.parse('2012-01-18 21:00:00')
              }
            }
          ],
          'prop-filters' => []
        }
        input = VObject::Reader.read(input)
        assert(validator.validate(input, filters))
      end

      # Pacific Standard Time, translates to America/Los_Angeles (GMT-8 in January)
      def test_outlook_timezone_name
        input = <<HI
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTIMEZONE
TZID:Pacific Standard Time
BEGIN:STANDARD
DTSTART:16010101T030000
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010101T020000
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
DTSTART;TZID=Pacific Standard Time:20120113T100000
DTEND;TZID=Pacific Standard Time:20120113T110000
END:VEVENT
END:VCALENDAR
HI
        pst = ActiveSupport::TimeZone.new(-8)
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
                'start' => pst.parse('2012-01-13 10:30:00'),
                'end'   => pst.parse('2012-01-13 10:30:00')
              }
            }
          ],
          'prop-filters' => []
        }
        input = VObject::Reader.read(input)
        assert(validator.validate(input, filters))
      end

      # X-LIC-LOCATION, translates to America/Los_Angeles (GMT-8 in January)
      def test_lib_i_cal_location_name
        input = <<HI
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTIMEZONE
TZID:My own timezone name
X-LIC-LOCATION:America/Los_Angeles
BEGIN:STANDARD
DTSTART:16010101T030000
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010101T020000
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
DTSTART;TZID=My own timezone name:20120113T100000
DTEND;TZID=My own timezone name:20120113T110000
END:VEVENT
END:VCALENDAR
HI

        la = ActiveSupport::TimeZone.new(-8)
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
                'start' => la.parse('2012-01-13 10:30:00'),
                'end'   => la.parse('2012-01-13 10:30:00')
              }
            }
          ],
          'prop-filters' => []
        }
        input = VObject::Reader.read(input)
        assert(validator.validate(input, filters))
      end
    end
  end
end
