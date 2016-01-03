module Tilia
  module CalDav
    module Backend
      module AbstractSequelTest
        def setup
          @sequel = sequel
          @backend = Sequel.new(@sequel)
        end

        def test_get_calendars_for_user_no_calendars
          calendars = @backend.calendars_for_user('principals/user2')
          assert_equal([], calendars)
        end

        def test_create_calendar_and_fetch
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT']),
            '{DAV:}displayname' => 'Hello!',
            '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp' => Xml::Property::ScheduleCalendarTransp.new('transparent')
          )
          calendars = @backend.calendars_for_user('principals/user2')

          element_check = {
            'id'                => returned_id,
            'uri'               => 'somerandomid',
            '{DAV:}displayname' => 'Hello!',
            '{urn:ietf:params:xml:ns:caldav}calendar-description' => nil,
            '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp' => Xml::Property::ScheduleCalendarTransp.new('transparent')
          }

          assert_kind_of(Array, calendars)
          assert_equal(1, calendars.size)

          element_check.each do |name, value|
            assert_has_key(name, calendars[0])
            assert_instance_equal(value, calendars[0][name])
          end
        end

        def test_update_calendar_and_fetch
          # Creating a new calendar
          new_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'myCalendar',
            '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp' => Xml::Property::ScheduleCalendarTransp.new('transparent')
          )

          # Updating the calendar
          @backend.update_calendar(new_id, prop_patch)
          result = prop_patch.commit

          # Verifying the result of the update
          assert(result)

          # Fetching all calendars from this user
          calendars = @backend.calendars_for_user('principals/user2')

          # Checking if all the information is still correct
          element_check = {
            'id'                => new_id,
            'uri'               => 'somerandomid',
            '{DAV:}displayname' => 'myCalendar',
            '{urn:ietf:params:xml:ns:caldav}calendar-description' => nil,
            '{urn:ietf:params:xml:ns:caldav}calendar-timezone' => nil,
            '{http://calendarserver.org/ns/}getctag' => 'http://sabre.io/ns/sync/2',
            '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp' => Xml::Property::ScheduleCalendarTransp.new('transparent')
          }

          assert_kind_of(Array, calendars)
          assert_equal(1, calendars.size)

          element_check.each do |name, value|
            assert_has_key(name, calendars[0])
            assert_instance_equal(value, calendars[0][name])
          end
        end

        def test_update_calendar_unknown_property
          # Creating a new calendar
          new_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'myCalendar',
            '{DAV:}yourmom'     => 'wittycomment'
          )

          # Updating the calendar
          @backend.update_calendar(new_id, prop_patch)
          prop_patch.commit

          # Verifying the result of the update
          assert_equal(
            {
              '{DAV:}yourmom' => 403,
              '{DAV:}displayname' => 424
            },
            prop_patch.result
          )
        end

        def test_delete_calendar
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT']),
            '{DAV:}displayname' => 'Hello!'
          )

          @backend.delete_calendar(returned_id)

          calendars = @backend.calendars_for_user('principals/user2')
          assert_equal([], calendars)
        end

        # @expectedException \Sabre\DAV\Exception
        def test_create_calendar_incorrect_component_set
          # Creating a new calendar
          assert_raises(Dav::Exception) do
            new_id = @backend.create_calendar(
              'principals/user2',
              'somerandomid',
              '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => 'blabla'
            )
          end
        end

        def test_create_calendar_object
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first

          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('20120101').to_i,
              lastoccurence: (Time.zone.parse('20120101') + 1.day).to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_get_multiple_objects
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'id-1', object)
          @backend.create_calendar_object(returned_id, 'id-2', object)

          check = [
            {
              'id' => 1,
              'etag' => "\"#{Digest::MD5.hexdigest(object)}\"",
              'uri' => 'id-1',
              'size' => object.bytesize,
              'calendardata' => object,
              'lastmodified' => nil,
              'calendarid' => returned_id
            },
            {
              'id' => 2,
              'etag' => "\"#{Digest::MD5.hexdigest(object)}\"",
              'uri' => 'id-2',
              'size' => object.bytesize,
              'calendardata' => object,
              'lastmodified' => nil,
              'calendarid' => returned_id
            }
          ]

          result = @backend.multiple_calendar_objects(returned_id, ['id-1', 'id-2'])

          check.each_with_index do |props, index|
            props.each do |key, value|
              if key != 'lastmodified'
                assert_equal(value, result[index][key])
              else
                assert_has_key(key, result[index])
              end
            end
          end
        end

        def test_create_calendar_object_no_component
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nEND:VTIMEZONE\r\nEND:VCALENDAR\r\n"

          assert_raises(Dav::Exception::BadRequest) do
            @backend.create_calendar_object(returned_id, 'random-id', object)
          end
        end

        def test_create_calendar_object_duration
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nDURATION:P2D\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('20120101').to_i,
              lastoccurence: (Time.zone.parse('20120101') + 2.days).to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_create_calendar_object_no_dtend
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE-TIME:20120101T100000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('2012-01-01 10:00:00').to_i,
              lastoccurence: Time.zone.parse('2012-01-01 10:00:00').to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_create_calendar_object_with_dtend
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE-TIME:20120101T100000Z\r\nDTEND:20120101T110000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('2012-01-01 10:00:00').to_i,
              lastoccurence: Time.zone.parse('2012-01-01 11:00:00').to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_create_calendar_object_infinite_reccurence
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE-TIME:20120101T100000Z\r\nRRULE:FREQ=DAILY\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('2012-01-01 10:00:00').to_i,
              lastoccurence: Time.zone.parse(Sequel::MAX_DATE).to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_create_calendar_object_ending_reccurence
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE-TIME:20120101T100000Z\r\nDTEND;VALUE=DATE-TIME:20120101T110000Z\r\nUID:foo\r\nRRULE:FREQ=DAILY;COUNT=1000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: Time.zone.parse('2012-01-01 10:00:00').to_i,
              lastoccurence: (Time.zone.parse('2012-01-01 11:00:00') + 999.days).to_i,
              componenttype: 'VEVENT'
            },
            row
          )
        end

        def test_create_calendar_object_task
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nDUE;VALUE=DATE-TIME:20120101T100000Z\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(returned_id, 'random-id', object)

          row = @sequel['SELECT etag, size, calendardata, firstoccurence, lastoccurence, componenttype FROM calendarobjects WHERE uri = "random-id"'].all.first
          assert_equal(
            {
              etag: Digest::MD5.hexdigest(object),
              size: object.bytesize,
              calendardata: object,
              firstoccurence: nil,
              lastoccurence: nil,
              componenttype: 'VTODO'
            },
            row
          )
        end

        def test_get_calendar_objects
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
          @backend.create_calendar_object(returned_id, 'random-id', object)

          data = @backend.calendar_objects(returned_id)

          assert_equal(1, data.size)
          data = data[0]

          assert_equal(returned_id, data['calendarid'])
          assert_equal('random-id', data['uri'])
          assert_equal(object.bytesize, data['size'])
        end

        def test_get_calendar_object_by_uid
          returned_id = @backend.create_calendar('principals/user2', 'somerandomid', {})

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
          @backend.create_calendar_object(returned_id, 'random-id', object)

          assert_nil(@backend.calendar_object_by_uid('principals/user2', 'bar'))
          assert_equal(
            'somerandomid/random-id',
            @backend.calendar_object_by_uid('principals/user2', 'foo')
          )
        end

        def test_update_calendar_object
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
          object2 = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20130101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
          @backend.create_calendar_object(returned_id, 'random-id', object)
          @backend.update_calendar_object(returned_id, 'random-id', object2)

          data = @backend.calendar_object(returned_id, 'random-id')

          assert_equal(object2, data['calendardata'])
          assert_equal(returned_id, data['calendarid'])
          assert_equal('random-id', data['uri'])
        end

        def test_delete_calendar_object
          returned_id = @backend.create_calendar(
            'principals/user2',
            'somerandomid',
            {}
          )

          object = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
          @backend.create_calendar_object(returned_id, 'random-id', object)
          @backend.delete_calendar_object(returned_id, 'random-id')

          data = @backend.calendar_object(returned_id, 'random-id')
          assert_nil(data)
        end

        def test_calendar_query_no_result
          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VJOURNAL',
                'comp-filters' => [],
                'prop-filters' => [],
                'is-not-defined' => false,
                'time-range' => nil
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal([], @backend.calendar_query(1, filters))
        end

        def test_calendar_query_todo
          @backend.create_calendar_object(1, 'todo', "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")

          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VTODO',
                'comp-filters' => [],
                'prop-filters' => [],
                'is-not-defined' => false,
                'time-range' => nil
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal(['todo'], @backend.calendar_query(1, filters))
        end

        def test_calendar_query_todo_not_match
          @backend.create_calendar_object(1, 'todo', "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")

          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VTODO',
                'comp-filters' => [],
                'prop-filters' => [
                  {
                    'name' => 'summary',
                    'text-match' => nil,
                    'time-range' => nil,
                    'param-filters' => [],
                    'is-not-defined' => false
                  }
                ],
                'is-not-defined' => false,
                'time-range' => nil
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal([], @backend.calendar_query(1, filters))
        end

        def test_calendar_query_no_filter
          @backend.create_calendar_object(1, 'todo', "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")

          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          result = @backend.calendar_query(1, filters)
          assert(result.include?('todo'))
          assert(result.include?('event'))
        end

        def test_calendar_query_time_range
          @backend.create_calendar_object(1, 'todo', "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event2', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20120103\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")

          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VEVENT',
                'comp-filters' => [],
                'prop-filters' => [],
                'is-not-defined' => false,
                'time-range' => {
                  'start' => Time.zone.parse('20120103'),
                  'end'   => Time.zone.parse('20120104')
                }
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal(
            ['event2'],
            @backend.calendar_query(1, filters)
          )
        end

        def test_calendar_query_time_range_no_end
          @backend.create_calendar_object(1, 'todo', "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20120101\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
          @backend.create_calendar_object(1, 'event2', "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20120103\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")

          filters = {
            'name' => 'VCALENDAR',
            'comp-filters' => [
              {
                'name' => 'VEVENT',
                'comp-filters' => [],
                'prop-filters' => [],
                'is-not-defined' => false,
                'time-range' => {
                  'start' => Time.zone.parse('20120102'),
                  'end' => nil
                }
              }
            ],
            'prop-filters' => [],
            'is-not-defined' => false,
            'time-range' => nil
          }

          assert_equal(
            ['event2'],
            @backend.calendar_query(1, filters)
          )
        end

        def test_get_changes
          id = @backend.create_calendar(
            'principals/user1',
            'bla',
            {}
          )

          result = @backend.changes_for_calendar(id, nil, 1)

          assert_equal(
            {
              'syncToken' => 1,
              'modified' => [],
              'deleted' => [],
              'added' => []
            },
            result
          )

          current_token = result['syncToken']

          dummy_todo = "BEGIN:VCALENDAR\r\nBEGIN:VTODO\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"

          @backend.create_calendar_object(id, 'todo1.ics', dummy_todo)
          @backend.create_calendar_object(id, 'todo2.ics', dummy_todo)
          @backend.create_calendar_object(id, 'todo3.ics', dummy_todo)
          @backend.update_calendar_object(id, 'todo1.ics', dummy_todo)
          @backend.delete_calendar_object(id, 'todo2.ics')

          result = @backend.changes_for_calendar(id, current_token, 1)

          assert_equal(
            {
              'syncToken' => 6,
              'modified'  => ['todo1.ics'],
              'deleted'   => ['todo2.ics'],
              'added'     => ['todo3.ics']
            },
            result
          )

          result = @backend.changes_for_calendar(id, nil, 1)

          assert_equal(
            {
              'syncToken' => 6,
              'modified' => [],
              'deleted' => [],
              'added' => ['todo1.ics', 'todo3.ics']
            },
            result
          )
        end

        def test_create_subscriptions
          props = {
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal.ics', false),
            '{DAV:}displayname' => 'cal',
            '{http://apple.com/ns/ical/}refreshrate' => 'P1W',
            '{http://apple.com/ns/ical/}calendar-color' => '#FF00FFFF',
            '{http://calendarserver.org/ns/}subscribed-strip-todos' => true,
            # '{http://calendarserver.org/ns/}subscribed-strip-alarms' => true,
            '{http://calendarserver.org/ns/}subscribed-strip-attachments' => true
          }

          @backend.create_subscription('principals/user1', 'sub1', props)

          subs = @backend.subscriptions_for_user('principals/user1')

          expected = props
          expected['id'] = 1
          expected['uri'] = 'sub1'
          expected['principaluri'] = 'principals/user1'

          expected.delete('{http://calendarserver.org/ns/}source')
          expected['source'] = 'http://example.org/cal.ics'

          assert_equal(1, subs.size)
          expected.each do |k, _v|
            assert_equal(subs[0][k], expected[k])
          end
        end

        def test_create_subscription_fail
          props = {}

          assert_raises(Dav::Exception::Forbidden) do
            @backend.create_subscription('principals/user1', 'sub1', props)
          end
        end

        def test_update_subscriptions
          props = {
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal.ics', false),
            '{DAV:}displayname' => 'cal',
            '{http://apple.com/ns/ical/}refreshrate' => 'P1W',
            '{http://apple.com/ns/ical/}calendar-color' => '#FF00FFFF',
            '{http://calendarserver.org/ns/}subscribed-strip-todos' => true,
            # '{http://calendarserver.org/ns/}subscribed-strip-alarms' => true,
            '{http://calendarserver.org/ns/}subscribed-strip-attachments' => true
          }

          @backend.create_subscription('principals/user1', 'sub1', props)

          new_props = {
            '{DAV:}displayname' => 'new displayname',
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal2.ics', false)
          }

          prop_patch = Dav::PropPatch.new(new_props)
          @backend.update_subscription(1, prop_patch)
          result = prop_patch.commit

          assert(result)

          subs = @backend.subscriptions_for_user('principals/user1')

          expected = props.merge(new_props)
          expected['id'] = 1
          expected['uri'] = 'sub1'
          expected['principaluri'] = 'principals/user1'

          expected.delete('{http://calendarserver.org/ns/}source')
          expected['source'] = 'http://example.org/cal2.ics'

          assert_equal(1, subs.size)
          expected.each do |k, _v|
            assert_equal(subs[0][k], expected[k])
          end
        end

        def test_update_subscriptions_fail
          props = {
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal.ics', false),
            '{DAV:}displayname' => 'cal',
            '{http://apple.com/ns/ical/}refreshrate' => 'P1W',
            '{http://apple.com/ns/ical/}calendar-color' => '#FF00FFFF',
            '{http://calendarserver.org/ns/}subscribed-strip-todos' => true,
            # '{http://calendarserver.org/ns/}subscribed-strip-alarms' => true,
            '{http://calendarserver.org/ns/}subscribed-strip-attachments' => true
          }

          @backend.create_subscription('principals/user1', 'sub1', props)

          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'new displayname',
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal2.ics', false),
            '{DAV:}unknown' => 'foo'
          )

          @backend.update_subscription(1, prop_patch)
          prop_patch.commit

          assert_equal(
            {
              '{DAV:}unknown' => 403,
              '{DAV:}displayname' => 424,
              '{http://calendarserver.org/ns/}source' => 424
            },
            prop_patch.result
          )
        end

        def test_delete_subscriptions
          props = {
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal.ics', false),
            '{DAV:}displayname' => 'cal',
            '{http://apple.com/ns/ical/}refreshrate' => 'P1W',
            '{http://apple.com/ns/ical/}calendar-color' => '#FF00FFFF',
            '{http://calendarserver.org/ns/}subscribed-strip-todos' => true,
            # '{http://calendarserver.org/ns/}subscribed-strip-alarms' => true,
            '{http://calendarserver.org/ns/}subscribed-strip-attachments' => true
          }

          @backend.create_subscription('principals/user1', 'sub1', props)

          new_props = {
            '{DAV:}displayname' => 'new displayname',
            '{http://calendarserver.org/ns/}source' => Dav::Xml::Property::Href.new('http://example.org/cal2.ics', false)
          }

          @backend.delete_subscription(1)

          subs = @backend.subscriptions_for_user('principals/user1')
          assert_equal(0, subs.size)
        end

        def test_scheduling_methods
          cal_data = "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"

          @backend.create_scheduling_object(
            'principals/user1',
            'schedule1.ics',
            cal_data
          )

          expected = {
            'calendardata' => cal_data,
            'uri' => 'schedule1.ics',
            'etag' => "\"#{Digest::MD5.hexdigest(cal_data)}\"",
            'size' => cal_data.bytesize
          }

          result = @backend.scheduling_object('principals/user1', 'schedule1.ics')
          expected.each do |k, v|
            assert_has_key(k, result)
            assert_equal(v, result[k])
          end

          results = @backend.scheduling_objects('principals/user1')

          assert_equal(1, results.size)
          result = results[0]
          expected.each do |k, v|
            assert_equal(v, result[k])
          end

          @backend.delete_scheduling_object('principals/user1', 'schedule1.ics')
          result = @backend.scheduling_object('principals/user1', 'schedule1.ics')

          assert_nil(result)
        end
      end
    end
  end
end
