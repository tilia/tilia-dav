require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class FreeBusyRequestTest < Minitest::Test
        def setup
          caldav_ns = "{#{Plugin::NS_CALDAV}}"
          calendars = [
            {
              'principaluri'                  => 'principals/user2',
              'id'                            => 1,
              'uri'                           => 'calendar1',
              caldav_ns + 'calendar-timezone' => "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nTZID:Europe/Berlin\r\nEND:VTIMEZONE\r\nEND:VCALENDAR"
            },
            {
              'principaluri'                         => 'principals/user2',
              'id'                                   => 2,
              'uri'                                  => 'calendar2',
              caldav_ns + 'schedule-calendar-transp' => Xml::Property::ScheduleCalendarTransp.new(Xml::Property::ScheduleCalendarTransp::TRANSPARENT)
            }
          ]
          calendarobjects = {
            1 => {
              '1.ics' => {
                'uri'          => '1.ics',
                'calendarid' => 1,
                'calendardata' => <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T130000
DURATION:PT1H
END:VEVENT
END:VCALENDAR
ICS
              }
            },
            2 => {
              '2.ics' => {
                'uri'          => '2.ics',
                'calendarid' => 2,
                'calendardata' => <<ICS
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20110101T080000
DURATION:PT1H
END:VEVENT
END:VCALENDAR
ICS

              }
            }
          }

          principal_backend = DavAcl::PrincipalBackend::Mock.new
          @caldav_backend = Backend::MockScheduling.new(calendars, calendarobjects)

          tree = [
            DavAcl::PrincipalCollection.new(principal_backend),
            CalendarRoot.new(principal_backend, @caldav_backend)
          ]

          @request = Http::Sapi.create_from_server_array(
            'CONTENT_TYPE' => 'text/calendar'
          )
          @response = Http::ResponseMock.new

          @server = Dav::ServerMock.new(tree)
          @server.http_request = @request
          @server.http_response = @response

          @acl_plugin = DavAcl::Plugin.new
          @server.add_plugin(@acl_plugin)

          auth_backend = Dav::Auth::Backend::Mock.new
          auth_backend.principal = 'principals/user1'
          @auth_plugin = Dav::Auth::Plugin.new(auth_backend)
          # Forcing authentication to work.
          @auth_plugin.before_method(@request, @response)
          @server.add_plugin(@auth_plugin)

          # CalDAV plugin
          @plugin = CalDav::Plugin.new
          @server.add_plugin(@plugin)

          # Scheduling plugin
          @plugin = Plugin.new
          @server.add_plugin(@plugin)
        end

        def test_wrong_content_type
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/plain'
          )

          assert(@plugin.http_post(@server.http_request, @server.http_response))
        end

        def test_not_found
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/blabla',
            'Content-Type' => 'text/calendar'
          )

          assert(@plugin.http_post(@server.http_request, @server.http_response))
        end

        def test_not_outbox
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/inbox',
            'Content-Type' => 'text/calendar'
          )

          assert(@plugin.http_post(@server.http_request, @server.http_response))
        end

        def test_no_itip_method
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
BEGIN:VFREEBUSY
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body
          assert_raises(Dav::Exception::BadRequest) do
            @plugin.http_post(@server.http_request, @server.http_response)
          end
        end

        def test_no_v_free_busy
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VEVENT
END:VEVENT
END:VCALENDAR
ICS

          @server.http_request.body = body
          assert_raises(Dav::Exception::NotImplemented) do
            @plugin.http_post(@server.http_request, @server.http_response)
          end
        end

        def test_incorrect_organizer
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:john@wayne.org
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body
          assert_raises(Dav::Exception::Forbidden) do
            @plugin.http_post(@server.http_request, @server.http_response)
          end
        end

        def test_no_attendees
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body
          assert_raises(Dav::Exception::BadRequest) do
            @plugin.http_post(@server.http_request, @server.http_response)
          end
        end

        def test_no_dt_start
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body
          assert_raises(Dav::Exception::BadRequest) do
            @plugin.http_post(@server.http_request, @server.http_response)
          end
        end

        def test_succeed
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
ATTENDEE:mailto:user3.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          # Lazily making the current principal an admin.
          @acl_plugin.admin_principals << 'principals/user1'

          refute(
            @plugin.http_post(@server.http_request, @response)
          )

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => ['application/xml'] },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<d:href>mailto:user3.sabredav@sabredav.org</d:href>',
            '<cal:request-status>2.0;Success</cal:request-status>',
            '<cal:request-status>3.7;Could not find principal</cal:request-status>',
            'FREEBUSY:20110101T120000Z/20110101T130000Z'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end

          refute(
            @response.body.index('FREEBUSY;FBTYPE=BUSY:20110101T080000Z/20110101T090000Z'),
            'The response body did contain free busy info from a transparent calendar.'
          )
        end

        # Testing if the freebusy request still works, even if there are no
        # calendars in the target users' account.
        def test_succeed_no_calendars
          # Deleting calendars
          @caldav_backend.delete_calendar(1)
          @caldav_backend.delete_calendar(2)

          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          # Lazily making the current principal an admin.
          @acl_plugin.admin_principals << 'principals/user1'

          refute(
            @plugin.http_post(@server.http_request, @response)
          )

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => ['application/xml'] },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<cal:request-status>2.0;Success</cal:request-status>'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end
        end

        def test_no_calendar_home_found
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          # Lazily making the current principal an admin.
          @acl_plugin.admin_principals << 'principals/user1'

          # Removing the calendar home
          @server.on(
            'propFind',
            lambda do |prop_find, _path|
              prop_find.set("{#{Plugin::NS_CALDAV}}calendar-home-set", nil, 403)
            end
          )

          refute(
            @plugin.http_post(@server.http_request, @response)
          )

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => ['application/xml'] },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<cal:request-status>3.7;No calendar-home-set property found</cal:request-status>'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end
        end

        def test_no_inbox_found
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          # Lazily making the current principal an admin.
          @acl_plugin.admin_principals << 'principals/user1'

          # Removing the inbox
          @server.on(
            'propFind',
            lambda do |prop_find, _path|
              prop_find.set("{#{Plugin::NS_CALDAV}}schedule-inbox-URL", nil, 403)
            end
          )

          refute(@plugin.http_post(@server.http_request, @response))

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => ['application/xml'] },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<cal:request-status>3.7;No schedule-inbox-URL property found</cal:request-status>'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end
        end

        def test_succeed_use_vavailability
          @server.http_request = Http::Request.new(
            'POST',
            '/calendars/user1/outbox',
            'Content-Type' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          # Lazily making the current principal an admin.
          @acl_plugin.admin_principals << 'principals/user1'

          # Adding VAVAILABILITY manually
          @server.on(
            'propFind',
            lambda do |prop_find, _path|
              prop_find.handle(
                "{#{Plugin::NS_CALDAV}}calendar-availability",
                lambda do
                  avail = <<ICS
BEGIN:VCALENDAR
BEGIN:VAVAILABILITY
DTSTART:20110101T000000Z
DTEND:20110102T000000Z
BEGIN:AVAILABLE
DTSTART:20110101T090000Z
DTEND:20110101T170000Z
END:AVAILABLE
END:VAVAILABILITY
END:VCALENDAR
ICS
                  return avail
                end
              )
            end
          )

          refute(@plugin.http_post(@server.http_request, @response))

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => ['application/xml'] },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<cal:request-status>2.0;Success</cal:request-status>',
            'FREEBUSY;FBTYPE=BUSY-UNAVAILABLE:20110101T080000Z/20110101T090000Z',
            'FREEBUSY:20110101T120000Z/20110101T130000Z',
            'FREEBUSY;FBTYPE=BUSY-UNAVAILABLE:20110101T170000Z/20110101T180000Z'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end
        end

        def test_no_privilege
          skip('Currently there\'s no "no privilege" situation')

          @server.http_request = Http::Sapi.create_from_server_array(
            'CONTENT_TYPE' => 'text/calendar',
            'REQUEST_METHOD' => 'POST',
            'PATH_INFO'    => '/calendars/user1/outbox'
          )

          body = <<ICS
BEGIN:VCALENDAR
METHOD:REQUEST
BEGIN:VFREEBUSY
ORGANIZER:mailto:user1.sabredav@sabredav.org
ATTENDEE:mailto:user2.sabredav@sabredav.org
DTSTART:20110101T080000Z
DTEND:20110101T180000Z
END:VFREEBUSY
END:VCALENDAR
ICS

          @server.http_request.body = body

          refute(@plugin.http_post(@server.http_request, @response))

          assert_equal(200, @response.status)
          assert_equal(
            { 'Content-Type' => 'application/xml' },
            @response.headers
          )

          strings = [
            '<d:href>mailto:user2.sabredav@sabredav.org</d:href>',
            '<cal:request-status>3.7;No calendar-home-set property found</cal:request-status>'
          ]

          strings.each do |string|
            assert(
              @response.body.index(string),
              "The response body did not contain: #{string} Full response: #{@response.body}"
            )
          end
        end
      end
    end
  end
end
