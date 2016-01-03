require 'test_helper'

module Tilia
  module CalDav
    class JCalTransformTest < DavServerTest
      def setup
        @setup_cal_dav = true
        @caldav_calendars = [
          {
            'id' => 1,
            'principaluri' => 'principals/user1',
            'uri' => 'foo'
          }
        ]
        @caldav_calendar_objects = {
          1 => {
            'bar.ics' => {
              'uri' => 'bar.ics',
              'calendarid' => 1,
              'calendardata' => "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
              'lastmodified' => nil
            }
          }
        }

        super
      end

      def test_get
        headers = {
          'Accept' => 'application/calendar+json'
        }
        request = Http::Request.new('GET', '/calendars/user1/foo/bar.ics', headers)

        response = request(request)

        body = response.body_as_string
        assert_equal(200, response.status, "Incorrect status code: #{body}")

        response = JSON.parse(body)
        # if (json_last_error != JSON_ERROR_NONE) {
        #     self.fail('Json decoding error: ' . json_last_error_msg)
        # }
        assert_equal(
          [
            'vcalendar',
            [],
            [
              [
                'vevent',
                [],
                []
              ]
            ]
          ],
          response
        )
      end

      def test_multi_get
        xml = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
    <d:prop>
        <c:calendar-data content-type="application/calendar+json" />
    </d:prop>
    <d:href>/calendars/user1/foo/bar.ics</d:href>
</c:calendar-multiget>
XML

        headers = {}
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/foo',
          headers,
          xml
        )

        response = request(request)

        assert_equal(207, response.status, "Full rsponse: #{response.body_as_string}")

        multi_status = @server.xml.parse(response.body_as_string)

        responses = multi_status.responses
        assert_equal(1, responses.size)

        response = responses[0].response_properties['200']['{urn:ietf:params:xml:ns:caldav}calendar-data']

        jresponse = JSON.parse(response)
        # if (json_last_error) {
        #     self.fail('Json decoding error: ' . json_last_error_msg . '. Full response: ' . response)
        # }
        assert_equal(
          [
            'vcalendar',
            [],
            [
              [
                'vevent',
                [],
                []
              ]
            ]
          ],
          jresponse
        )
      end

      def test_calendar_query_depth1
        xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
    <d:prop>
        <c:calendar-data content-type="application/calendar+json" />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

        headers = {
          'Depth' => '1'
        }
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/foo',
          headers,
          xml
        )

        response = request(request)

        assert_equal(207, response.status, "Invalid response code. Full body: #{response.body_as_string}")

        multi_status = @server.xml.parse(response.body_as_string)

        responses = multi_status.responses

        assert_equal(1, responses.size)

        response = responses[0].response_properties['200']['{urn:ietf:params:xml:ns:caldav}calendar-data']
        response = JSON.parse(response)
        # if (json_last_error) {
        #     self.fail('Json decoding error: ' . json_last_error_msg)
        # }
        assert_equal(
          [
            'vcalendar',
            [],
            [
              [
                'vevent',
                [],
                []
              ]
            ]
          ],
          response
        )
      end

      def test_calendar_query_depth0
        xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
    <d:prop>
        <c:calendar-data content-type="application/calendar+json" />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

        headers = {
          'Depth' => '0'
        }
        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/foo/bar.ics',
          headers,
          xml
        )

        response = request(request)

        assert_equal(207, response.status, "Invalid response code. Full body: #{response.body_as_string}")

        multi_status = @server.xml.parse(response.body_as_string)

        responses = multi_status.responses

        assert_equal(1, responses.size)

        response = responses[0].response_properties['200']['{urn:ietf:params:xml:ns:caldav}calendar-data']
        response = JSON.parse(response)
        # if (json_last_error) {
        #     self.fail('Json decoding error: ' . json_last_error_msg)
        # }
        assert_equal(
          [
            'vcalendar',
            [],
            [
              [
                'vevent',
                [],
                []
              ]
            ]
          ],
          response
        )
      end

      def test_validate_i_calendar
        input = [
          'vcalendar',
          [],
          [
            [
              'vevent',
              [
                ['uid', {}, 'text', 'foo']
              ],
              []
            ]
          ]
        ]
        input = Box.new(input.to_json)
        @caldav_plugin.before_write_content(
          'calendars/user1/foo/bar.ics',
          @server.tree.node_for_path('calendars/user1/foo/bar.ics'),
          input,
          Box.new # modified
        )

        assert_equal("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:foo\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n", input.value)
      end
    end
  end
end
