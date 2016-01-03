require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class InboxTest < Minitest::Test
        def test_setup
          inbox = Inbox.new(
            Backend::MockScheduling.new,
            'principals/user1'
          )
          assert_equal('inbox', inbox.name)
          assert_equal([], inbox.children)
          assert_equal('principals/user1', inbox.owner)
          assert_equal(nil, inbox.group)

          assert_equal(
            [
              {
                'privilege' => '{DAV:}read',
                'principal' => '{DAV:}authenticated',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}write-properties',
                'principal' => 'principals/user1',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}unbind',
                'principal' => 'principals/user1',
                'protected' => true
              },
              {
                'privilege' => '{DAV:}unbind',
                'principal' => 'principals/user1/calendar-proxy-write',
                'protected' => true
              },
              {
                'privilege' => '{urn:ietf:params:xml:ns:caldav}schedule-deliver-invite',
                'principal' => '{DAV:}authenticated',
                'protected' => true
              },
              {
                'privilege' => '{urn:ietf:params:xml:ns:caldav}schedule-deliver-reply',
                'principal' => '{DAV:}authenticated',
                'protected' => true
              }
            ],
            inbox.acl
          )

          ok = false
          assert_raises(Dav::Exception::MethodNotAllowed) do
            inbox.acl = []
          end
        end

        def test_get_supported_privilege_set
          inbox = Inbox.new(
            Backend::MockScheduling.new,
            'principals/user1'
          )
          r = inbox.supported_privilege_set

          ok = 0
          r['aggregates'].each do |priv|
            next unless priv['privilege'] == "{#{Plugin::NS_CALDAV}}schedule-deliver"
            ok += 1
            priv['aggregates'].each do |subpriv|
              ok += 1 if subpriv['privilege'] == "{#{Plugin::NS_CALDAV}}schedule-deliver-invite"
              ok += 1 if subpriv['privilege'] == "{#{Plugin::NS_CALDAV}}schedule-deliver-reply"
            end
          end
          assert_equal(3, ok, "We're missing one or more privileges")
        end

        def test_get_children
          backend = Backend::MockScheduling.new
          inbox = Inbox.new(
            backend,
            'principals/user1'
          )

          assert_equal(
            0,
            inbox.children.size
          )
          backend.create_scheduling_object('principals/user1', 'schedule1.ics', "BEGIN:VCALENDAR\r\nEND:VCALENDAR")
          assert_equal(
            1,
            inbox.children.size
          )
          assert_kind_of(Schedule::SchedulingObject, inbox.children[0])
          assert_equal(
            'schedule1.ics',
            inbox.children[0].name
          )
        end

        def test_create_file
          backend = Backend::MockScheduling.new
          inbox = Inbox.new(
            backend,
            'principals/user1'
          )

          assert_equal(
            0,
            inbox.children.size
          )
          inbox.create_file('schedule1.ics', "BEGIN:VCALENDAR\r\nEND:VCALENDAR")
          assert_equal(
            1,
            inbox.children.size
          )
          assert_kind_of(Schedule::SchedulingObject, inbox.children[0])
          assert_equal(
            'schedule1.ics',
            inbox.children[0].name
          )
        end

        def test_calendar_query
          backend = Backend::MockScheduling.new
          inbox = Inbox.new(
            backend,
            'principals/user1'
          )

          assert_equal(
            0,
            inbox.children.size
          )
          backend.create_scheduling_object('principals/user1', 'schedule1.ics', "BEGIN:VCALENDAR\r\nEND:VCALENDAR")
          assert_equal(
            ['schedule1.ics'],
            inbox.calendar_query(

              'name'           => 'VCALENDAR',
              'comp-filters'   => [],
              'prop-filters'   => [],
              'is-not-defined' => false
            )
          )
        end
      end
    end
  end
end
