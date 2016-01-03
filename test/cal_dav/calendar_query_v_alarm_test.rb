require 'test_helper'

module Tilia
  module CalDav
    class CalendarQueryVAlarmTest < Minitest::Test
      # This test is specifically for a time-range query on a VALARM, contained
      # in a VEVENT that's recurring
      def test_valarm
        vcalendar = VObject::Component::VCalendar.new

        vevent = vcalendar.create_component('VEVENT')
        vevent['RRULE'] = 'FREQ=MONTHLY'
        vevent['DTSTART'] = '20120101T120000Z'
        vevent['UID'] = 'bla'

        valarm = vcalendar.create_component('VALARM')
        valarm['TRIGGER'] = '-P15D'
        vevent.add(valarm)

        vcalendar.add(vevent)

        filter = {
          'name' => 'VCALENDAR',
          'is-not-defined' => false,
          'time-range' => nil,
          'prop-filters' => [],
          'comp-filters' => [
            {
              'name' => 'VEVENT',
              'is-not-defined' => false,
              'time-range' => nil,
              'prop-filters' => [],
              'comp-filters' => [
                {
                  'name' => 'VALARM',
                  'is-not-defined' => false,
                  'prop-filters' => [],
                  'comp-filters' => [],
                  'time-range' => {
                    'start' => Time.zone.parse('2012-05-10'),
                    'end' => Time.zone.parse('2012-05-20')
                  }
                }
              ]
            }
          ]
        }

        validator = CalendarQueryValidator.new
        assert(validator.validate(vcalendar, filter))

        vcalendar = VObject::Component::VCalendar.new

        # A limited recurrence rule, should return false
        vevent = vcalendar.create_component('VEVENT')
        vevent['RRULE'] = 'FREQ=MONTHLY;COUNT=1'
        vevent['DTSTART'] = '20120101T120000Z'
        vevent['UID'] = 'bla'

        valarm = vcalendar.create_component('VALARM')
        valarm['TRIGGER'] = '-P15D'
        vevent.add(valarm)

        vcalendar.add(vevent)

        refute(validator.validate(vcalendar, filter))
      end

      def test_alarm_way_before
        vcalendar = VObject::Component::VCalendar.new

        vevent = vcalendar.create_component('VEVENT')
        vevent['DTSTART'] = '20120101T120000Z'
        vevent['UID'] = 'bla'

        valarm = vcalendar.create_component('VALARM')
        valarm['TRIGGER'] = '-P2W1D'
        vevent.add(valarm)

        vcalendar.add(vevent)

        filter = {
          'name' => 'VCALENDAR',
          'is-not-defined' => false,
          'time-range' => nil,
          'prop-filters' => [],
          'comp-filters' => [
            {
              'name' => 'VEVENT',
              'is-not-defined' => false,
              'time-range' => nil,
              'prop-filters' => [],
              'comp-filters' => [
                {
                  'name' => 'VALARM',
                  'is-not-defined' => false,
                  'prop-filters' => [],
                  'comp-filters' => [],
                  'time-range' => {
                    'start' => Time.zone.parse('2011-12-10'),
                    'end' => Time.zone.parse('2011-12-20')
                  }
                }
              ]
            }
          ]
        }

        validator = CalendarQueryValidator.new
        assert(validator.validate(vcalendar, filter))
      end
    end
  end
end
