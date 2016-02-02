require 'test_helper'

module Tilia
  module CalDav
    module Schedule
      class OutboxPostTest < DavServerTest
        def setup
          @setup_cal_dav = true
          @setup_acl = true
          @auto_login = 'user1'
          @setup_cal_dav_scheduling = true

          super
        end

        def test_post_pass_thru_not_found
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'POST',
            'PATH_INFO'    => '/notfound',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )

          assert_http_status(501, req)
        end

        def test_post_pass_thru_not_text_calendar
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'POST',
            'PATH_INFO'    => '/calendars/user1/outbox'
          )

          assert_http_status(501, req)
        end

        def test_post_pass_thru_no_out_box
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD' => 'POST',
            'PATH_INFO'    => '/calendars',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )

          assert_http_status(501, req)
        end

        def test_invalid_ical_body
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'  => 'POST',
            'PATH_INFO'       => '/calendars/user1/outbox',
            'HTTP_ORIGINATOR' => 'mailto:user1.sabredav@sabredav.org',
            'HTTP_RECIPIENT'  => 'mailto:user2@example.org',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )
          req.body = 'foo'

          assert_http_status(400, req)
        end

        def test_no_vevent
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'  => 'POST',
            'PATH_INFO'       => '/calendars/user1/outbox',
            'HTTP_ORIGINATOR' => 'mailto:user1.sabredav@sabredav.org',
            'HTTP_RECIPIENT'  => 'mailto:user2@example.org',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR\r
BEGIN:VTIMEZONE\r
END:VTIMEZONE\r
END:VCALENDAR\r
ICS

          req.body = body

          assert_http_status(400, req)
        end

        def test_no_method
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'  => 'POST',
            'PATH_INFO'       => '/calendars/user1/outbox',
            'HTTP_ORIGINATOR' => 'mailto:user1.sabredav@sabredav.org',
            'HTTP_RECIPIENT'  => 'mailto:user2@example.org',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR\r
BEGIN:VTIMEZONE\r
END:VTIMEZONE\r
END:VCALENDAR\r
ICS

          req.body = body

          assert_http_status(400, req)
        end

        def test_unsupported_method
          req = Http::Sapi.create_from_server_array(
            'REQUEST_METHOD'  => 'POST',
            'PATH_INFO'       => '/calendars/user1/outbox',
            'HTTP_ORIGINATOR' => 'mailto:user1.sabredav@sabredav.org',
            'HTTP_RECIPIENT'  => 'mailto:user2@example.org',
            'HTTP_CONTENT_TYPE' => 'text/calendar'
          )

          body = <<ICS
BEGIN:VCALENDAR\r
METHOD:PUBLISH
BEGIN:VEVENT\r
END:VEVENT\r
END:VCALENDAR\r
ICS

          req.body = body

          assert_http_status(501, req)
        end
      end
    end
  end
end
