require 'test_helper'

module Tilia
  module CalDav
    module Backend
      class AbstractTest < Minitest::Test
        def test_update_calendar
          abstract = AbstractMock.new
          prop_patch = Dav::PropPatch.new('{DAV:}displayname' => 'anything')

          abstract.update_calendar('randomid', prop_patch)
          result = prop_patch.commit

          refute(result)
        end

        def test_calendar_query
          abstract = AbstractMock.new
          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VEVENT',
                'comp-filters' => [],
                'prop-filters' => [],
                'is-not-defined' => false,
                'time-range' => {}
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal(['event1.ics'], abstract.calendar_query(1, filters))
        end

        def test_get_calendar_object_by_uid
          abstract = AbstractMock.new

          assert_nil(abstract.calendar_object_by_uid('principal1', 'zim'))
          assert_equal('cal1/event1.ics', abstract.calendar_object_by_uid('principal1', 'foo'))
          assert_nil(abstract.calendar_object_by_uid('principal3', 'foo'))
          assert_nil(abstract.calendar_object_by_uid('principal1', 'shared'))
        end

        def test_get_multiple_calendar_objects
          abstract = AbstractMock.new

          result = abstract.multiple_calendar_objects(
            1,
            [
              'event1.ics',
              'task1.ics'
            ]
          )

          expected = [
            {
              'id' => 1,
              'calendarid' => 1,
              'uri' => 'event1.ics',
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
            },
            {
              'id' => 2,
              'calendarid' => 1,
              'uri' => 'task1.ics',
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"
            }
          ]

          assert_equal(expected, result)
        end
      end

      class AbstractMock < AbstractBackend
        def calendars_for_user(_principal_uri)
          [
            {
              'id' => 1,
              'principaluri' => 'principal1',
              'uri' => 'cal1'
            },
            {
              'id' => 2,
              'principaluri' => 'principal1',
              '{http://sabredav.org/ns}owner-principal' => 'principal2',
              'uri' => 'cal1'
            }
          ]
        end

        def create_calendar(principal_uri, calendar_uri, properties)
        end

        def delete_calendar(calendar_id)
        end

        def calendar_objects(calendar_id)
          case calendar_id
          when 1
            return [
              {
                'id' => 1,
                'calendarid' => 1,
                'uri' => 'event1.ics'
              },
              {
                'id' => 2,
                'calendarid' => 1,
                'uri' => 'task1.ics'
              }
            ]
          when 2
            return [
              {
                'id' => 3,
                'calendarid' => 2,
                'uri' => 'shared-event.ics'
              }
            ]
          end
        end

        def calendar_object(_calendar_id, object_uri)
          case object_uri
          when 'event1.ics'
            {
              'id' => 1,
              'calendarid' => 1,
              'uri' => 'event1.ics',
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
            }
          when 'task1.ics'
            {
              'id' => 2,
              'calendarid' => 1,
              'uri' => 'task1.ics',
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"
            }
          when 'shared-event.ics'
            {
              'id' => 3,
              'calendarid' => 2,
              'uri' => 'event1.ics',
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:shared\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
            }
          end
        end

        def create_calendar_object(calendar_id, object_uri, calendar_data)
        end

        def update_calendar_object(calendar_id, object_uri, calendar_data)
        end

        def delete_calendar_object(calendar_id, object_uri)
        end
      end
    end
  end
end
