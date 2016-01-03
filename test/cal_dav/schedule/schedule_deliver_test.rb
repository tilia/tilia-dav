require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class ScheduleDeliverTest < DavServerTest
        # Save the setup method for later use as parent_setup
        alias_method :parent_setup, :setup

        def setup
          @setup_cal_dav = true
          @setup_cal_dav_scheduling = true
          @setup_acl = true
          @auto_login = 'user1'

          @caldav_calendars = [
              {
                  'principaluri' => 'principals/user1',
                  'uri' => 'cal',
              },
              {
                  'principaluri' => 'principals/user2',
                  'uri' => 'cal',
              },
          ]

          @calendar_object_uri = '/calendars/user1/cal/object.ics'

          super
        end

        def test_new_invite
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(nil, new_object)
          assert_items_in_inbox('user2', 1)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=1.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_new_on_wrong_collection
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @calendar_object_uri = '/calendars/user1/object.ics'
          new_object = deliver(nil, new_object)
          assert_items_in_inbox('user2', 0)
        end

        def test_new_invite_scheduling_disabled
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(nil, new_object, true)
          assert_items_in_inbox('user2', 0)
        end

        def test_updated_invite
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS
          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 1)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=1.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_updated_invite_scheduling_disabled
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS
          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(old_object, new_object, true)
          assert_items_in_inbox('user2', 0)
        end

        def test_updated_invite_wrong_path
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS
          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @calendar_object_uri = '/calendars/user1/inbox/foo.ics'
          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 0)
        end

        def test_deleted_invite
          new_object = nil

          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 1)
        end

        def test_deleted_invite_scheduling_disabled
          new_object = nil

          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(old_object, new_object, true)
          assert_items_in_inbox('user2', 0)
        end

        # A MOVE request will trigger an unbind on a scheduling resource.
        #
        # However, we must not treat it as a cancellation, it just got moved to a
        # different calendar.
        def test_unbind_ignored_on_move
          new_object = nil

          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS


          @server.http_request.method = 'MOVE'
          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 0)
        end

        def test_deleted_invite_wrong_url
          new_object = nil

          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @calendar_object_uri = '/calendars/user1/inbox/foo.ics'
          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 0)
        end

        def test_reply
          old_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user2.sabredav@sabredav.org
ATTENDEE;PARTSTAT=ACCEPTED:mailto:user2.sabredav@sabredav.org
ATTENDEE:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user3.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user2.sabredav@sabredav.org
ATTENDEE;PARTSTAT=ACCEPTED:mailto:user2.sabredav@sabredav.org
ATTENDEE;PARTSTAT=ACCEPTED:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user3.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          put_path('calendars/user2/cal/foo.ics', old_object)

          new_object = deliver(old_object, new_object)
          assert_items_in_inbox('user2', 1)
          assert_items_in_inbox('user1', 0)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER;SCHEDULE-STATUS=1.2:mailto:user2.sabredav@sabredav.org
ATTENDEE;PARTSTAT=ACCEPTED:mailto:user2.sabredav@sabredav.org
ATTENDEE;PARTSTAT=ACCEPTED:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user3.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_unknown_user
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user3.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=3.7:mailto:user3.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_no_inbox_url
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @server.on(
            'propFind',
            lambda do |prop_find, path|
              prop_find.set("{#{Plugin::NS_CALDAV }}schedule-inbox-URL", nil, 403)
            end
          )
          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=5.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_no_calendar_home_set
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @server.on(
            'propFind',
            lambda do |prop_find, path|
              prop_find.set("{#{Plugin::NS_CALDAV }}calendar-home-set", nil, 403)
            end
          )
          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=5.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_no_default_calendar
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @server.on(
            'propFind',
            lambda do |prop_find, path|
              prop_find.set("{#{Plugin::NS_CALDAV }}schedule-default-calendar-URL", nil, 403)
            end
          )
          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=5.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_no_scheduler
          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          @server.remove_all_listeners('schedule')
          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=5.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def test_invite_no_acl_plugin
          @setup_acl = false
          parent_setup

          new_object = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          new_object = deliver(nil, new_object)

          expected = <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:foo
DTSTART:20140811T230000Z
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE;SCHEDULE-STATUS=5.2:mailto:user2.sabredav@sabredav.org
END:VEVENT
END:VCALENDAR
ICS

          assert_v_object_equals(
            expected,
            new_object
          )
        end

        def deliver(old_object, new_object, disable_scheduling = false)
          @server.http_request.url = @calendar_object_uri
          @server.http_request.update_header('Schedule-Reply','F') if disable_scheduling

          if old_object && new_object
            # update
            put_path(@calendar_object_uri, old_object)

            stream = StringIO.new
            stream.write(new_object)
            stream.rewind
            modified = false

            stream_box = Box.new(stream)
            modified_box = Box.new(modified)
            @server.emit(
              'beforeWriteContent',
              [
                @calendar_object_uri,
                @server.tree.node_for_path(@calendar_object_uri),
                stream_box,
                modified_box
              ]
            )

            new_object = stream_box.value if modified_box.value
          elsif old_object && !new_object
            # delete
            put_path(@calendar_object_uri, old_object)

            @caldav_schedule_plugin.before_unbind(@calendar_object_uri)
          else
            stream = StringIO.new
            stream.write(new_object)
            stream.rewind
            modified = false

            stream_box = Box.new(stream)
            modified_box = Box.new(modified)
            @server.emit(
              'beforeCreateFile',
              [
                @calendar_object_uri,
                stream_box,
                @server.tree.node_for_path(::File.dirname(@calendar_object_uri)),
                modified_box
              ]
            )

            new_object = stream_box.value if modified_box.value
          end

          new_object
        end

        # Creates or updates a node at the specified path.
        #
        # This circumvents sabredav's internal server apis, so all events and
        # access control is skipped.
        #
        # @param string path
        # @param string data
        # @return void
        def put_path(path, data)
          (parent, base) = Http::UrlUtil::split_path(path)
          parent_node = @server.tree.node_for_path(parent)

          parent_node.create_file(base, data)
        end

        def assert_items_in_inbox(user, count)
          inbox_node = @server.tree.node_for_path("calendars/#{user}/inbox")
          assert_equal(count, inbox_node.children.size)
        end
      end
    end
  end
end
