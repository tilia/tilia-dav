require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class DeliverNewEventTest < DavServerTest
        def setup
          @setup_cal_dav = true
          @setup_cal_dav_scheduling = true
          @setup_acl = true
          @auto_login = 'user1'

          super

          @caldav_backend.create_calendar(
            'principals/user1',
            'default',
            {}
          )
          @caldav_backend.create_calendar(
            'principals/user2',
            'default',
            {}
          )
        end

        def test_delivery
          request = Http::Request.new('PUT', '/calendars/user1/default/foo.ics')
          request.body = <<ICS
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//Mac OS X 10.9.1//EN
CALSCALE:GREGORIAN
BEGIN:VEVENT
CREATED:20140109T204404Z
UID:AADC6438-18CF-4B52-8DD2-EF9AD75ADE83
DTEND;TZID=America/Toronto:20140107T110000
TRANSP:OPAQUE
ATTENDEE;CN="Adminstrator";CUTYPE=INDIVIDUAL;PARTSTAT=ACCEPTED:mailto:user1.sabredav@sabredav.org
ATTENDEE;CN="Roxy Kesh";CUTYPE=INDIVIDUAL;EMAIL="user2.sabredav@sabrdav.org"
 PARTSTAT=NEEDS-ACTION;ROLE=REQ-PARTICIPANT;RSVP=TRUE:mailto:user2.sabredav@sabredav.org
SUMMARY:Just testing!
DTSTART;TZID=America/Toronto:20140107T100000
DTSTAMP:20140109T204422Z
ORGANIZER;CN="Administrator":mailto:user1.sabredav@sabredav.org
SEQUENCE:4
END:VEVENT
END:VCALENDAR
ICS

          messages = []
          @server.on('schedule', -> (message) { messages << message })

          response = request(request)

          assert_equal(201, response.status, "Incorrect status code received. Response body: #{response.body_as_string}")

          result = request(Http::Request.new('GET', '/calendars/user1/default/foo.ics')).body
          result_v_obj = VObject::Reader.read(result)

          assert_equal(
            '1.2',
            result_v_obj['VEVENT']['ATTENDEE'][1]['SCHEDULE-STATUS'].value
          )

          assert_equal(1, messages.size)
          message = messages[0]

          assert_kind_of(VObject::ITip::Message, message)
          assert_equal('mailto:user2.sabredav@sabredav.org', message.recipient)
          assert_equal('Roxy Kesh', message.recipient_name)
          assert_equal('mailto:user1.sabredav@sabredav.org', message.sender)
          assert_equal('Administrator', message.sender_name.to_s)
          assert_equal('REQUEST', message.method)

          assert_equal('REQUEST', message.message['METHOD'].value)
        end
      end
    end
  end
end
