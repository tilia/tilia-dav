require 'test_helper'

module Tilia
  module CalDav
    class FreeBusyReportTest < Minitest::Test
      def setup
        obj1 = <<ics
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20111005T120000Z
DURATION:PT1H
END:VEVENT
END:VCALENDAR
ics

        obj2 = StringIO.new
        obj2.write(<<ics
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20121005T120000Z
DURATION:PT1H
END:VEVENT
END:VCALENDAR
ics
                  )
        obj2.rewind

        obj3 = <<ics
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20111006T120000
DURATION:PT1H
END:VEVENT
END:VCALENDAR
ics

        calendar_data = {
          1 => {
            'obj1' => {
              'calendarid' => 1,
              'uri' => 'event1.ics',
              'calendardata' => obj1
            },
            'obj2' => {
              'calendarid' => 1,
              'uri' => 'event2.ics',
              'calendardata' => obj2
            },
            'obj3' => {
              'calendarid' => 1,
              'uri' => 'event3.ics',
              'calendardata' => obj3
            }
          }
        }

        caldav_backend = Backend::Mock.new([], calendar_data)

        calendar = Calendar.new(
          caldav_backend,
          'id' => 1,
          'uri' => 'calendar',
          'principaluri' => 'principals/user1',
          "{#{Plugin::NS_CALDAV}}calendar-timezone" => "BEGIN:VCALENDAR\r\nBEGIN:VTIMEZONE\r\nTZID:Europe/Berlin\r\nEND:VTIMEZONE\r\nEND:VCALENDAR"
        )

        @server = Dav::ServerMock.new([calendar])

        request = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/calendar'
        )
        @server.http_request = request
        @server.http_response = Http::ResponseMock.new

        @plugin = Plugin.new
        @server.add_plugin(@plugin)
      end

      def test_free_busy_report
        report_xml = <<XML
<?xml version="1.0"?>
<c:free-busy-query xmlns:c="urn:ietf:params:xml:ns:caldav">
    <c:time-range start="20111001T000000Z" end="20111101T000000Z" />
</c:free-busy-query>
XML

        root_elem = Box.new('')
        report = @server.xml.parse(report_xml, nil, root_elem)
        @plugin.report(root_elem.value, report, nil)

        assert_equal(200, @server.http_response.status)
        assert_equal('text/calendar', @server.http_response.header('Content-Type'))
        assert(@server.http_response.body.index('BEGIN:VFREEBUSY'))
        assert(@server.http_response.body.index('20111005T120000Z/20111005T130000Z'))
        assert(@server.http_response.body.index('20111006T100000Z/20111006T110000Z'))
      end

      def test_free_busy_report_no_time_range
        report_xml = <<XML
<?xml version="1.0"?>
<c:free-busy-query xmlns:c="urn:ietf:params:xml:ns:caldav">
</c:free-busy-query>
XML

        root_elem = Box.new('')
        assert_raises(Dav::Exception::BadRequest) do
          report = @server.xml.parse(report_xml, nil, root_elem)
        end
      end

      def test_free_busy_report_wrong_node
        request = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/'
        )
        @server.http_request = request

        report_xml = <<XML
<?xml version="1.0"?>
<c:free-busy-query xmlns:c="urn:ietf:params:xml:ns:caldav">
    <c:time-range start="20111001T000000Z" end="20111101T000000Z" />
</c:free-busy-query>
XML

        root_elem = Box.new('')
        report = @server.xml.parse(report_xml, nil, root_elem)
        assert_raises(Dav::Exception::NotImplemented) do
          @plugin.report(root_elem.value, report, nil)
        end
      end

      def test_free_busy_report_no_acl_plugin
        @server = Dav::ServerMock.new
        @plugin = Plugin.new
        @server.add_plugin(@plugin)

        request = Http::Sapi.create_from_server_array(
          'PATH_INFO'    => '/'
        )
        @server.http_request = request

        report_xml = <<XML
<?xml version="1.0"?>
<c:free-busy-query xmlns:c="urn:ietf:params:xml:ns:caldav">
    <c:time-range start="20111001T000000Z" end="20111101T000000Z" />
</c:free-busy-query>
XML

        root_elem = Box.new('')
        report = @server.xml.parse(report_xml, nil, root_elem)
        assert_raises(Dav::Exception) do
          @plugin.report(root_elem.value, report, nil)
        end
      end
    end
  end
end
