require 'test_helper'

module Tilia
  module CalDav
    class ValidateICalTest < DavServerTest
      def setup
        @setup_cal_dav = true
        @setup_cal_dav_sharing = true

        @caldav_calendars = [
          {
            'id' => 'calendar1',
            'principaluri' => 'principals/admin',
            'uri' => 'calendar1',
            '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT', 'VTODO', 'VJOURNAL'])
          },
          {
            'id' => 'calendar2',
            'principaluri' => 'principals/admin',
            'uri' => 'calendar2',
            '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VTODO', 'VJOURNAL'])
          }
        ]

        super
      end

      def test_create_file
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )

        response = request(request)

        assert_equal(415, response.status)
      end

      def test_create_file_valid
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(201, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
        assert_equal(
          {
            'X-Sabre-Version' => [Dav::Version::VERSION],
            'Content-Length' => ['0'],
            'ETag' => ["\"#{Digest::MD5.hexdigest("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")}\""]
          },
          response.headers
        )

        expected = {
          'uri'          => 'blabla.ics',
          'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
          'calendarid'   => 'calendar1',
          'lastmodified' => nil
        }

        assert_equal(expected, @caldav_backend.calendar_object('calendar1', 'blabla.ics'))
      end

      def test_create_file_no_components
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(400, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_create_file_no_uid
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(400, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_create_file_v_card
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCARD\r\nEND:VCARD\r\n"

        response = request(request)

        assert_equal(415, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_create_file2_components
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nBEGIN:VJOURNAL\r\nUID:foo\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(400, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_create_file2_uids
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:bar\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(400, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_create_file_wrong_componen
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nEND:VTIMEZONE\r\nBEGIN:VFREEBUSY\r\nUID:foo\r\nEND:VFREEBUSY\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(400, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_update_file
        @caldav_backend.create_calendar_object('calendar1', 'blabla.ics', 'foo')
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )

        response = request(request)

        assert_equal(415, response.status)
      end

      def test_update_file_parsable_body
        @caldav_backend.create_calendar_object('calendar1', 'blabla.ics', 'foo')
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        body = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        request.body = body

        response = request(request)

        assert_equal(204, response.status)

        expected = {
          'uri'          => 'blabla.ics',
          'calendardata' => body,
          'calendarid'   => 'calendar1',
          'lastmodified' => nil
        }

        assert_equal(expected, @caldav_backend.calendar_object('calendar1', 'blabla.ics'))
      end

      def test_create_file_invalid_component
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar2/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(403, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_update_file_invalid_component
        @caldav_backend.create_calendar_object('calendar2', 'blabla.ics', 'foo')
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar2/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(403, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      # What we are testing here, is if we send in a latin1 character, the
      # server should automatically transform this into UTF-8.
      #
      # More importantly. If any transformation happens, the etag must no longer
      # be returned by the server.
      def test_create_file_modified
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'PATH_INFO'    => '/calendars/admin/calendar1/blabla.ics'
        )
        request.body = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nSUMMARY:Meeting in M\xfcnster\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(201, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
        assert_nil(response.header('ETag'))
      end
    end
  end
end
