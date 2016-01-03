require 'test_helper'

module Tilia
  module CalDav
    class CalendarQueryValidatorTest < Minitest::Test
      def test_top_level_fail
        validator = CalendarQueryValidator.new
        vcal = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
END:VEVENT
END:VCALENDAR
ICS
        vcal = VObject::Reader.read(vcal)
        refute(validator.validate(vcal, 'name' => 'VFOO'))
      end

      def test_valid
        provider.each_with_index do |data, _i|
          (ical_object, filters, outcome) = data

          validator = CalendarQueryValidator.new

          # Wrapping filter in a VCALENDAR component filter, as this is always
          # there anyway.
          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [filters],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          v_object = VObject::Reader.read(ical_object)

          case outcome
          when 0
            refute(validator.validate(v_object, filters))
          when 1
            assert(validator.validate(v_object, filters))
          when -1
            assert_raises(::Exception) do
              validator.validate(v_object, filters)
            end
          end
        end
      end

      def provider
        utc = ActiveSupport::TimeZone.new('UTC')

        blob1 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:hi
END:VEVENT
END:VCALENDAR
yow

        blob2 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:hi
BEGIN:VALARM
ACTION:DISPLAY
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob3 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:hi
DTSTART;VALUE=DATE:20110704
END:VEVENT
END:VCALENDAR
yow
        blob4 = <<yow
BEGIN:VCARD
VERSION:3.0
FN:Evert
END:VCARD
yow

        blob5 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DTEND:20110102T120000Z
END:VEVENT
END:VCALENDAR
yow

        blob6 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DURATION:PT5H
END:VEVENT
END:VCALENDAR
yow

        blob7 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;VALUE=DATE:20110101
END:VEVENT
END:VCALENDAR
yow

        blob8 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
END:VEVENT
END:VCALENDAR
yow

        blob9 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
DTSTART:20110101T120000Z
DURATION:PT1H
END:VTODO
END:VCALENDAR
yow
        blob10 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
DTSTART:20110101T120000Z
DUE:20110101T130000Z
END:VTODO
END:VCALENDAR
yow
        blob11 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
DTSTART:20110101T120000Z
END:VTODO
END:VCALENDAR
yow

        blob12 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
DUE:20110101T130000Z
END:VTODO
END:VCALENDAR
yow

        blob13 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
COMPLETED:20110101T130000Z
CREATED:20110101T110000Z
END:VTODO
END:VCALENDAR
yow

        blob14 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
COMPLETED:20110101T130000Z
END:VTODO
END:VCALENDAR
yow

        blob15 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
CREATED:20110101T110000Z
END:VTODO
END:VCALENDAR
yow

        blob16 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
END:VTODO
END:VCALENDAR
yow

        blob17 = <<yow
BEGIN:VCALENDAR
BEGIN:VJOURNAL
END:VJOURNAL
END:VCALENDAR
yow

        blob18 = <<yow
BEGIN:VCALENDAR
BEGIN:VJOURNAL
DTSTART:20110101T120000Z
END:VJOURNAL
END:VCALENDAR
yow

        blob19 = <<yow
BEGIN:VCALENDAR
BEGIN:VJOURNAL
DTSTART;VALUE=DATE:20110101
END:VJOURNAL
END:VCALENDAR
yow

        blob20 = <<yow
BEGIN:VCALENDAR
BEGIN:VFREEBUSY
END:VFREEBUSY
END:VCALENDAR
yow

        blob21 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
BEGIN:VALARM
TRIGGER:-PT1H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob22 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
BEGIN:VALARM
TRIGGER;VALUE=DURATION:-PT1H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob23 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
BEGIN:VALARM
TRIGGER;VALUE=DURATION;RELATED=END:-PT1H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob24 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DTEND:20110101T130000Z
BEGIN:VALARM
TRIGGER;VALUE=DURATION;RELATED=END:-PT2H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob25 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DURATION:PT1H
BEGIN:VALARM
TRIGGER;VALUE=DURATION;RELATED=END:-PT2H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob26 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DURATION:PT1H
BEGIN:VALARM
TRIGGER;VALUE=DATE-TIME:20110101T110000Z
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob27 = <<yow
BEGIN:VCALENDAR
BEGIN:VTODO
DTSTART:20110101T120000Z
DUE:20110101T130000Z
BEGIN:VALARM
TRIGGER;VALUE=DURATION;RELATED=END:-PT2H
END:VALARM
END:VTODO
END:VCALENDAR
yow

        blob28 = <<yow
BEGIN:VCALENDAR
BEGIN:VJOURNAL
DTSTART:20110101T120000Z
BEGIN:VALARM
TRIGGER;VALUE=DURATION;RELATED=END:-PT2H
END:VALARM
END:VJOURNAL
END:VCALENDAR
yow

        blob29 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DURATION:PT1H
BEGIN:VALARM
TRIGGER;VALUE=DATE-TIME:20110101T090000Z
REPEAT:2
DURATION:PT1H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob30 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T120000Z
DURATION:PT1H
BEGIN:VALARM
TRIGGER;VALUE=DATE-TIME:20110101T090000Z
DURATION:PT1H
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        blob31 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foobar
DTSTART:20080101T120000Z
DURATION:PT1H
RRULE:FREQ=YEARLY
END:VEVENT
END:VCALENDAR
yow

        blob32 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foobar
DTSTART:20080102T120000Z
DURATION:PT1H
RRULE:FREQ=YEARLY
END:VEVENT
END:VCALENDAR
yow
        blob33 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foobar
DTSTART;VALUE=DATE:20120628
RRULE:FREQ=DAILY
END:VEVENT
END:VCALENDAR
yow
        blob34 = <<yow
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foobar
DTSTART;VALUE=DATE:20120628
RRULE:FREQ=DAILY
BEGIN:VALARM
TRIGGER:P52W
END:VALARM
END:VEVENT
END:VCALENDAR
yow

        filter1 = {
          'name' => 'VEVENT',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => nil
        }

        filter2 = filter1.deep_dup
        filter2['name'] = 'VTODO'

        filter3 = filter1.deep_dup
        filter3['is-not-defined'] = true

        filter4 = filter1.deep_dup
        filter4['name'] = 'VTODO'
        filter4['is-not-defined'] = true

        filter5 = filter1.deep_dup
        filter5['comp-filters'] = [
          {
            'name' => 'VALARM',
            'is-not-defined' => false,
            'comp-filters' => [],
            'prop-filters' => [],
            'time-range' => nil
          }
        ]

        filter6 = filter1.deep_dup
        filter6['prop-filters'] = [
          {
            'name' => 'SUMMARY',
            'is-not-defined' => false,
            'param-filters' => [],
            'time-range' => nil,
            'text-match' => nil
          }
        ]

        filter7 = filter6.deep_dup
        filter7['prop-filters'][0]['name'] = 'DESCRIPTION'

        filter8 = filter6.deep_dup
        filter8['prop-filters'][0]['is-not-defined'] = true

        filter9 = filter7.deep_dup
        filter9['prop-filters'][0]['is-not-defined'] = true

        filter10 = filter5.deep_dup
        filter10['prop-filters'] = filter6['prop-filters']

        # Param filters
        filter11 = filter1.deep_dup
        filter11['prop-filters'] = [
          {
            'name' => 'DTSTART',
            'is-not-defined' => false,
            'param-filters' => [
              {
                'name' => 'VALUE',
                'is-not-defined' => false,
                'text-match' => nil
              }
            ],
            'time-range' => nil,
            'text-match' => nil
          }
        ]

        filter12 = filter11.deep_dup
        filter12['prop-filters'][0]['param-filters'][0]['name'] = 'TZID'

        filter13 = filter11.deep_dup
        filter13['prop-filters'][0]['param-filters'][0]['is-not-defined'] = true

        filter14 = filter12.deep_dup
        filter14['prop-filters'][0]['param-filters'][0]['is-not-defined'] = true

        # Param text filter
        filter15 = filter11.deep_dup
        filter15['prop-filters'][0]['param-filters'][0]['text-match'] = {
          'collation' => 'i;ascii-casemap',
          'value' => 'dAtE',
          'negate-condition' => false
        }

        filter16 = filter15.deep_dup
        filter16['prop-filters'][0]['param-filters'][0]['text-match']['collation'] = 'i;octet'

        filter17 = filter15.deep_dup
        filter17['prop-filters'][0]['param-filters'][0]['text-match']['negate-condition'] = true

        filter18 = filter15.deep_dup
        filter18['prop-filters'][0]['param-filters'][0]['text-match']['negate-condition'] = true
        filter18['prop-filters'][0]['param-filters'][0]['text-match']['collation'] = 'i;octet'

        # prop + text
        filter19 = filter5.deep_dup
        filter19['comp-filters'][0]['prop-filters'] = [
          {
            'name' => 'action',
            'is-not-defined' => false,
            'time-range' => nil,
            'param-filters' => [],
            'text-match' => {
              'collation' => 'i;ascii-casemap',
              'value' => 'display',
              'negate-condition' => false
            }
          }
        ]

        # Time range
        filter20 = {
          'name' => 'VEVENT',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => {
            'start' => utc.parse('2011-01-01 10:00:00'),
            'end' => utc.parse('2011-01-01 13:00:00')
          }
        }

        # Time range, no end date
        filter21 = filter20.deep_dup
        filter21['time-range']['end'] = nil

        # Time range, no start date
        filter22 = filter20.deep_dup
        filter22['time-range']['start'] = nil

        # Time range, other dates
        filter23 = filter20.deep_dup
        filter23['time-range'] = {
          'start' => utc.parse('2011-02-01 10:00:00'),
          'end' => utc.parse('2011-02-01 13:00:00')
        }

        # Time range
        filter24 = {
          'name' => 'VTODO',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => {
            'start' => utc.parse('2011-01-01 12:45:00'),
            'end' => utc.parse('2011-01-01 13:15:00')
          }
        }

        # Time range, other dates (1 month in the future)
        filter25 = filter24.deep_dup
        filter25['time-range'] = {
          'start' => utc.parse('2011-02-01 10:00:00'),
          'end' => utc.parse('2011-02-01 13:00:00')
        }

        filter26 = filter24.deep_dup
        filter26['time-range'] = {
          'start' => utc.parse('2011-01-01 11:45:00'),
          'end' => utc.parse('2011-01-01 12:15:00')
        }

        # Time range for VJOURNAL
        filter27 = {
          'name' => 'VJOURNAL',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => {
            'start' => utc.parse('2011-01-01 12:45:00'),
            'end' => utc.parse('2011-01-01 13:15:00')
          }
        }

        filter28 = filter27.deep_dup
        filter28['time-range'] = {
          'start' => utc.parse('2011-01-01 11:45:00'),
          'end' => utc.parse('2011-01-01 12:15:00')
        }

        # Time range for VFREEBUSY
        filter29 = {
          'name' => 'VFREEBUSY',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => {
            'start' => utc.parse('2011-01-01 12:45:00'),
            'end' => utc.parse('2011-01-01 13:15:00')
          }
        }

        # Time range filter on property
        filter30 = {
          'name' => 'VEVENT',
          'comp-filters' => [],
          'prop-filters' => [
            {
              'name' => 'DTSTART',
              'is-not-defined' => false,
              'param-filters' => [],
              'time-range' => {
                'start' => utc.parse('2011-01-01 10:00:00'),
                'end' => utc.parse('2011-01-01 13:00:00')
              },
              'text-match' => nil
            }
          ],
          'is-not-defined' => false,
          'time-range' => nil
        }

        # Time range for alarm
        filter31 = {
          'name' => 'VEVENT',
          'prop-filters' => [],
          'comp-filters' => [
            {
              'name' => 'VALARM',
              'is-not-defined' => false,
              'comp-filters' => [],
              'prop-filters' => [],
              'time-range' => {
                'start' => utc.parse('2011-01-01 10:45:00'),
                'end' => utc.parse('2011-01-01 11:15:00')
              },
              'text-match' => nil
            }
          ],
          'is-not-defined' => false,
          'time-range' => nil
        }

        filter32 = filter31.deep_dup
        filter32['comp-filters'][0]['time-range'] = {
          'start' => utc.parse('2011-01-01 11:45:00'),
          'end' => utc.parse('2011-01-01 12:15:00')
        }

        filter33 = filter31.deep_dup
        filter33['name'] = 'VTODO'
        filter34 = filter32.deep_dup
        filter34['name'] = 'VTODO'
        filter35 = filter31.deep_dup
        filter35['name'] = 'VJOURNAL'
        filter36 = filter32.deep_dup
        filter36['name'] = 'VJOURNAL'

        # Time range filter on non-datetime property
        filter37 = {
          'name' => 'VEVENT',
          'comp-filters' => [],
          'prop-filters' => [
            {
              'name' => 'SUMMARY',
              'is-not-defined' => false,
              'param-filters' => [],
              'time-range' => {
                'start' => utc.parse('2011-01-01 10:00:00'),
                'end' => utc.parse('2011-01-01 13:00:00')
              },
              'text-match' => nil
            }
          ],
          'is-not-defined' => false,
          'time-range' => nil
        }

        filter38 = {
          'name' => 'VEVENT',
          'comp-filters' => [],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => {
            'start' => utc.parse('2012-07-01 00:00:00'),
            'end' => utc.parse('2012-08-01 00:00:00')
          }
        }

        filter39 = {
          'name' => 'VEVENT',
          'comp-filters' => [
            {
              'name' => 'VALARM',
              'comp-filters' => [],
              'prop-filters' => [],
              'is-not-defined' => false,
              'time-range' => {
                'start' => utc.parse('2012-09-01 00:00:00'),
                'end' => utc.parse('2012-10-01 00:00:00')
              }
            }
          ],
          'prop-filters' => [],
          'is-not-defined' => false,
          'time-range' => nil
        }

        [

          # Component check

          [blob1, filter1, 1],
          [blob1, filter2, 0],
          [blob1, filter3, 0],
          [blob1, filter4, 1],

          # Subcomponent check (4)
          [blob1, filter5, 0],
          [blob2, filter5, 1],

          # Property checki (6)
          [blob1, filter6, 1],
          [blob1, filter7, 0],
          [blob1, filter8, 0],
          [blob1, filter9, 1],

          # Subcomponent + property (10)
          [blob2, filter10, 1],

          # Param filter (11)
          [blob3, filter11, 1],
          [blob3, filter12, 0],
          [blob3, filter13, 0],
          [blob3, filter14, 1],

          # Param + text (15)
          [blob3, filter15, 1],
          [blob3, filter16, 0],
          [blob3, filter17, 0],
          [blob3, filter18, 1],

          # Prop + text (19)
          [blob2, filter19, 1],

          # Incorrect object (vcard) (20)
          [blob4, filter1, -1],

          # Time-range for event (21)
          [blob5, filter20, 1],
          [blob6, filter20, 1],
          [blob7, filter20, 1],
          [blob8, filter20, 1],

          [blob5, filter21, 1],
          [blob5, filter22, 1],

          [blob5, filter23, 0],
          [blob6, filter23, 0],
          [blob7, filter23, 0],
          [blob8, filter23, 0],

          # Time-range for todo (31)
          [blob9, filter24, 1],
          [blob9, filter25, 0],
          [blob9, filter26, 1],
          [blob10, filter24, 1],
          [blob10, filter25, 0],
          [blob10, filter26, 1],

          [blob11, filter24, 0],
          [blob11, filter25, 0],
          [blob11, filter26, 1],

          [blob12, filter24, 1],
          [blob12, filter25, 0],
          [blob12, filter26, 0],

          [blob13, filter24, 1],
          [blob13, filter25, 0],
          [blob13, filter26, 1],

          [blob14, filter24, 1],
          [blob14, filter25, 0],
          [blob14, filter26, 0],

          [blob15, filter24, 1],
          [blob15, filter25, 1],
          [blob15, filter26, 1],

          [blob16, filter24, 1],
          [blob16, filter25, 1],
          [blob16, filter26, 1],

          # Time-range for journals (55)
          [blob17, filter27, 0],
          [blob17, filter28, 0],
          [blob18, filter27, 0],
          [blob18, filter28, 1],
          [blob19, filter27, 1],
          [blob19, filter28, 1],

          # Time-range for free-busy (61)
          [blob20, filter29, -1],

          # Time-range on property (62)
          [blob5, filter30, 1],
          [blob3, filter37, -1],
          [blob3, filter30, 0],

          # Time-range on alarm in vevent (65)
          [blob21, filter31, 1],
          [blob21, filter32, 0],
          [blob22, filter31, 1],
          [blob22, filter32, 0],
          [blob23, filter31, 1],
          [blob23, filter32, 0],
          [blob24, filter31, 1],
          [blob24, filter32, 0],
          [blob25, filter31, 1],
          [blob25, filter32, 0],
          [blob26, filter31, 1],
          [blob26, filter32, 0],

          # Time-range on alarm for vtodo (77)
          [blob27, filter33, 1],
          [blob27, filter34, 0],

          # Time-range on alarm for vjournal (79)
          [blob28, filter35, -1],
          [blob28, filter36, -1],

          # Time-range on alarm with duration (81)
          [blob29, filter31, 1],
          [blob29, filter32, 0],
          [blob30, filter31, 0],
          [blob30, filter32, 0],

          # Time-range with RRULE (85)
          [blob31, filter20, 1],
          [blob32, filter20, 0],

          # Bug reported on mailing list, related to all-day events (87)
          # [blob33, filter38, 1],

          # Event in timerange, but filtered alarm is in the far future (88).
          [blob34, filter39, 0]
        ]
      end
    end
  end
end
