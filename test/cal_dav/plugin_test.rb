require 'test_helper'

module Tilia
  module CalDav
    class PluginTest < Minitest::Test
      def setup
        caldav_ns = '{urn:ietf:params:xml:ns:caldav}'

        @caldav_backend = Backend::Mock.new(
          [
            {
              'id'                                           => 1,
              'uri'                                          => 'UUID-123467',
              'principaluri'                                 => 'principals/user1',
              '{DAV:}displayname'                            => 'user1 calendar',
              caldav_ns + 'calendar-description'             => 'Calendar description',
              '{http://apple.com/ns/ical/}calendar-order'    => '1',
              '{http://apple.com/ns/ical/}calendar-color'    => '#FF0000',
              caldav_ns + 'supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
            },
            {
              'id'                                           => 2,
              'uri'                                          => 'UUID-123468',
              'principaluri'                                 => 'principals/user1',
              '{DAV:}displayname'                            => 'user1 calendar2',
              caldav_ns + 'calendar-description'             => 'Calendar description',
              '{http://apple.com/ns/ical/}calendar-order'    => '1',
              '{http://apple.com/ns/ical/}calendar-color'    => '#FF0000',
              caldav_ns + 'supported-calendar-component-set' => Xml::Property::SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
            }
          ],
          1 => {
            'UUID-2345' => {
              'calendardata' => DatabaseUtil.get_test_calendar_data
            }
          }
        )

        principal_backend = DavAcl::PrincipalBackend::Mock.new
        principal_backend.update_group_member_set('principals/admin/calendar-proxy-read', ['principals/user1'])
        principal_backend.update_group_member_set('principals/admin/calendar-proxy-write', ['principals/user1'])
        principal_backend.add_principal(
          'uri' => 'principals/admin/calendar-proxy-read'
        )
        principal_backend.add_principal(
          'uri' => 'principals/admin/calendar-proxy-write'
        )

        calendars = CalendarRoot.new(principal_backend, @caldav_backend)
        principals = Principal::Collection.new(principal_backend)

        root = Dav::SimpleCollection.new('root')
        root.add_child(calendars)
        root.add_child(principals)

        @server = Dav::ServerMock.new(root)
        @server.sapi = Http::SapiMock.new
        @server.debug_exceptions = true
        @server.base_uri = '/'
        @plugin = Plugin.new
        @server.add_plugin(@plugin)

        # Adding ACL plugin
        @server.add_plugin(DavAcl::Plugin.new)

        # Adding Auth plugin, and ensuring that we are logged in.
        auth_backend = Dav::Auth::Backend::Mock.new
        auth_backend.principal = 'principals/user1'
        auth_plugin = Dav::Auth::Plugin.new(auth_backend)
        auth_plugin.before_method(Http::Request.new, Http::Response.new)
        @server.add_plugin(auth_plugin)

        # This forces a login
        auth_plugin.before_method(Http::Request.new, Http::Response.new)

        @response = Http::ResponseMock.new
        @server.http_response = @response
      end

      def test_simple
        assert_equal(['MKCALENDAR'], @plugin.http_methods('calendars/user1/randomnewcalendar'))
        assert_equal(['calendar-access', 'calendar-proxy'], @plugin.features)
        assert_equal(
          'caldav',
          @plugin.plugin_info['name']
        )
      end

      def test_unknown_method_pass_through
        request = Http::Request.new('MKBREAKFAST', '/')

        @server.http_request = request
        @server.exec

        assert_equal(501, @response.status, "Incorrect status returned. Full response body: #{@response.body_as_string}")
      end

      def test_report_pass_through
        request = Http::Request.new(
          'REPORT',
          '/',
          'Content-Type' => 'application/xml'
        )
        request.body = '<?xml version="1.0"?><s:somereport xmlns:s="http://www.rooftopsolutions.nl/NS/example" />'

        @server.http_request = request
        @server.exec

        assert_equal(415, @response.status)
      end

      def test_mk_calendar_bad_location
        request = Http::Request.new('MKCALENDAR', '/blabla')

        body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
  <C:mkcalendar xmlns:D="DAV:"
                xmlns:C="urn:ietf:params:xml:ns:caldav">
     <D:set>
       <D:prop>
         <D:displayname>Lisa\'s Events</D:displayname>
         <C:calendar-description xml:lang="en"
   >Calendar restricted to events.</C:calendar-description>
         <C:supported-calendar-component-set>
           <C:comp name="VEVENT"/>
         </C:supported-calendar-component-set>
         <C:calendar-timezone><![CDATA[BEGIN:VCALENDAR
   PRODID:-//Example Corp.//CalDAV Client//EN
   VERSION:2.0
   BEGIN:VTIMEZONE
   TZID:US-Eastern
   LAST-MODIFIED:19870101T000000Z
   BEGIN:STANDARD
   DTSTART:19671029T020000
   RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
   TZOFFSETFROM:-0400
   TZOFFSETTO:-0500
   TZNAME:Eastern Standard Time (US & Canada)
   END:STANDARD
   BEGIN:DAYLIGHT
   DTSTART:19870405T020000
   RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=4
   TZOFFSETFROM:-0500
   TZOFFSETTO:-0400
   TZNAME:Eastern Daylight Time (US & Canada)
   END:DAYLIGHT
   END:VTIMEZONE
   END:VCALENDAR
   ]]></C:calendar-timezone>
       </D:prop>
     </D:set>
   </C:mkcalendar>
XML

        request.body = body
        @server.http_request = request
        @server.exec

        assert_equal(403, @response.status)
      end

      def test_mk_calendar_no_parent_node
        request = Http::Request.new('MKCALENDAR', '/doesntexist/calendar')

        body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
   <C:mkcalendar xmlns:D="DAV:"
                 xmlns:C="urn:ietf:params:xml:ns:caldav">
     <D:set>
       <D:prop>
         <D:displayname>Lisa\'s Events</D:displayname>
         <C:calendar-description xml:lang="en"
   >Calendar restricted to events.</C:calendar-description>
         <C:supported-calendar-component-set>
           <C:comp name="VEVENT"/>
         </C:supported-calendar-component-set>
         <C:calendar-timezone><![CDATA[BEGIN:VCALENDAR
   PRODID:-//Example Corp.//CalDAV Client//EN
   VERSION:2.0
   BEGIN:VTIMEZONE
   TZID:US-Eastern
   LAST-MODIFIED:19870101T000000Z
   BEGIN:STANDARD
   DTSTART:19671029T020000
   RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
   TZOFFSETFROM:-0400
   TZOFFSETTO:-0500
   TZNAME:Eastern Standard Time (US & Canada)
   END:STANDARD
   BEGIN:DAYLIGHT
   DTSTART:19870405T020000
   RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=4
   TZOFFSETFROM:-0500
   TZOFFSETTO:-0400
   TZNAME:Eastern Daylight Time (US & Canada)
   END:DAYLIGHT
   END:VTIMEZONE
   END:VCALENDAR
   ]]></C:calendar-timezone>
       </D:prop>
     </D:set>
   </C:mkcalendar>
XML

        request.body = body
        @server.http_request = request
        @server.exec

        assert_equal(409, @response.status)
      end

      def test_mk_calendar_existing_calendar
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'MKCALENDAR',
          'PATH_INFO'      => '/calendars/user1/UUID-123467'
        )

        body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
   <C:mkcalendar xmlns:D="DAV:"
                 xmlns:C="urn:ietf:params:xml:ns:caldav">
     <D:set>
       <D:prop>
         <D:displayname>Lisa\'s Events</D:displayname>
         <C:calendar-description xml:lang="en"
   >Calendar restricted to events.</C:calendar-description>
         <C:supported-calendar-component-set>
           <C:comp name="VEVENT"/>
         </C:supported-calendar-component-set>
         <C:calendar-timezone><![CDATA[BEGIN:VCALENDAR
   PRODID:-//Example Corp.//CalDAV Client//EN
   VERSION:2.0
   BEGIN:VTIMEZONE
   TZID:US-Eastern
   LAST-MODIFIED:19870101T000000Z
   BEGIN:STANDARD
   DTSTART:19671029T020000
   RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
   TZOFFSETFROM:-0400
   TZOFFSETTO:-0500
   TZNAME:Eastern Standard Time (US & Canada)
   END:STANDARD
   BEGIN:DAYLIGHT
   DTSTART:19870405T020000
   RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=4
   TZOFFSETFROM:-0500
   TZOFFSETTO:-0400
   TZNAME:Eastern Daylight Time (US & Canada)
   END:DAYLIGHT
   END:VTIMEZONE
   END:VCALENDAR
   ]]></C:calendar-timezone>
       </D:prop>
     </D:set>
   </C:mkcalendar>
XML

        request.body = body
        @server.http_request = request
        @server.exec

        assert_equal(405, @response.status)
      end

      def test_mk_calendar_succeed
        request = Http::Request.new('MKCALENDAR', '/calendars/user1/NEWCALENDAR')

        timezone = <<ICAL
BEGIN:VCALENDAR
PRODID:-//Example Corp.//CalDAV Client//EN
VERSION:2.0
BEGIN:VTIMEZONE
TZID:US-Eastern
LAST-MODIFIED:19870101T000000Z
BEGIN:STANDARD
DTSTART:19671029T020000
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
TZNAME:Eastern Standard Time (US & Canada)
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19870405T020000
RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=4
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
TZNAME:Eastern Daylight Time (US & Canada)
END:DAYLIGHT
END:VTIMEZONE
END:VCALENDAR
ICAL

        body = <<XML
<?xml version="1.0" encoding="utf-8" ?>
   <C:mkcalendar xmlns:D="DAV:"
                 xmlns:C="urn:ietf:params:xml:ns:caldav">
     <D:set>
       <D:prop>
         <D:displayname>Lisa\'s Events</D:displayname>
         <C:calendar-description xml:lang="en"
   >Calendar restricted to events.</C:calendar-description>
         <C:supported-calendar-component-set>
           <C:comp name="VEVENT"/>
         </C:supported-calendar-component-set>
         <C:calendar-timezone><![CDATA[#{timezone}]]></C:calendar-timezone>
       </D:prop>
     </D:set>
   </C:mkcalendar>
XML

        request.body = body
        @server.http_request = request
        @server.exec

        assert_equal(201, @response.status, "Invalid response code received. Full response body: #{@response.body_as_string}")

        calendars = @caldav_backend.calendars_for_user('principals/user1')
        assert_equal(3, calendars.size)

        new_calendar = nil
        calendars.each do |calendar|
          if calendar['uri'] == 'NEWCALENDAR'
            new_calendar = calendar
            break
          end
        end

        assert_kind_of(Hash, new_calendar)

        keys = {
          'uri'                                                             => 'NEWCALENDAR',
          'id'                                                              => nil,
          '{urn:ietf:params:xml:ns:caldav}calendar-description'             => 'Calendar restricted to events.',
          '{urn:ietf:params:xml:ns:caldav}calendar-timezone'                => timezone,
          '{DAV:}displayname'                                               => 'Lisa\'s Events',
          '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => nil
        }

        keys.each do |key, value|
          assert_has_key(key, new_calendar)

          next if value.nil?

          assert_equal(value, new_calendar[key])
        end

        sccs = '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'
        assert(new_calendar[sccs].is_a?(Xml::Property::SupportedCalendarComponentSet))
        assert_equal(['VEVENT'], new_calendar[sccs].value)
      end

      def test_mk_calendar_empty_body_succeed
        request = Http::Request.new('MKCALENDAR', '/calendars/user1/NEWCALENDAR')

        request.body = ''
        @server.http_request = request
        @server.exec

        assert_equal(201, @response.status, "Invalid response code received. Full response body: #{@response.body_as_string}")

        calendars = @caldav_backend.calendars_for_user('principals/user1')
        assert_equal(3, calendars.size)

        new_calendar = nil
        calendars.each do |calendar|
          if calendar['uri'] == 'NEWCALENDAR'
            new_calendar = calendar
            break
          end
        end

        assert_kind_of(Hash, new_calendar)

        keys = {
          'uri'                                                             => 'NEWCALENDAR',
          'id'                                                              => nil,
          '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' => nil
        }

        keys.each do |key, value|
          assert_has_key(key, new_calendar)

          next if value.nil?

          assert_equal(value, new_calendar[key])
        end

        sccs = '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set'
        assert(new_calendar[sccs].is_a?(Xml::Property::SupportedCalendarComponentSet))
        assert_equal(['VEVENT', 'VTODO'], new_calendar[sccs].value)
      end

      def test_mk_calendar_bad_xml
        request = Http::Request.new('MKCALENDAR', '/blabla')
        body = 'This is not xml'

        request.body = body
        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status)
      end

      def test_principal_properties
        http_request = Http::Request.new(
          'FOO',
          '/blabla',
          'Host' => 'sabredav.org'
        )
        @server.http_request = http_request

        props = @server.properties_for_path(
          '/principals/user1',
          [
            "{#{Plugin::NS_CALDAV}}calendar-home-set",
            "{#{Plugin::NS_CALENDARSERVER}}calendar-proxy-read-for",
            "{#{Plugin::NS_CALENDARSERVER}}calendar-proxy-write-for",
            "{#{Plugin::NS_CALENDARSERVER}}notification-URL",
            "{#{Plugin::NS_CALENDARSERVER}}email-address-set"
          ]
        )

        assert(props[0])
        assert_has_key(200, props[0])

        assert_has_key('{urn:ietf:params:xml:ns:caldav}calendar-home-set', props[0][200])
        prop = props[0][200]['{urn:ietf:params:xml:ns:caldav}calendar-home-set']
        assert_kind_of(Dav::Xml::Property::Href, prop)
        assert_equal('calendars/user1/', prop.href)

        assert_has_key('{http://calendarserver.org/ns/}calendar-proxy-read-for', props[0][200])
        prop = props[0][200]['{http://calendarserver.org/ns/}calendar-proxy-read-for']
        assert_kind_of(Dav::Xml::Property::Href, prop)
        assert_equal(['principals/admin/'], prop.hrefs)

        assert_has_key('{http://calendarserver.org/ns/}calendar-proxy-write-for', props[0][200])
        prop = props[0][200]['{http://calendarserver.org/ns/}calendar-proxy-write-for']
        assert_kind_of(Dav::Xml::Property::Href, prop)
        assert_equal(['principals/admin/'], prop.hrefs)

        assert_has_key("{#{Plugin::NS_CALENDARSERVER}}email-address-set", props[0][200])
        prop = props[0][200]["{#{Plugin::NS_CALENDARSERVER}}email-address-set"]
        assert_kind_of(Xml::Property::EmailAddressSet, prop)
        assert_equal(['user1.sabredav@sabredav.org'], prop.value)
      end

      def test_supported_report_set_property_non_calendar
        props = @server.properties_for_path(
          '/calendars/user1',
          [
            '{DAV:}supported-report-set'
          ]
        )

        assert(props[0])
        assert_has_key(200, props[0])
        assert_has_key('{DAV:}supported-report-set', props[0][200])

        prop = props[0][200]['{DAV:}supported-report-set']

        assert_kind_of(Dav::Xml::Property::SupportedReportSet, prop)
        value = [
          '{DAV:}expand-property',
          '{DAV:}principal-property-search',
          '{DAV:}principal-search-property-set'
        ]
        assert_equal(value, prop.value)
      end

      def test_supported_report_set_property
        props = @server.properties_for_path(
          '/calendars/user1/UUID-123467',
          [
            '{DAV:}supported-report-set'
          ]
        )

        assert(props[0])
        assert_has_key(200, props[0])
        assert_has_key('{DAV:}supported-report-set', props[0][200])

        prop = props[0][200]['{DAV:}supported-report-set']

        assert_kind_of(Dav::Xml::Property::SupportedReportSet, prop)
        value = [
          '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
          '{urn:ietf:params:xml:ns:caldav}calendar-query',
          '{urn:ietf:params:xml:ns:caldav}free-busy-query',
          '{DAV:}expand-property',
          '{DAV:}principal-property-search',
          '{DAV:}principal-search-property-set'
        ]
        assert_equal(value, prop.value)
      end

      def test_supported_report_set_user_calendars
        @server.add_plugin(Dav::Sync::Plugin.new)

        props = @server.properties_for_path(
          '/calendars/user1',
          [
            '{DAV:}supported-report-set'
          ]
        )

        assert(props[0])
        assert_has_key(200, props[0])
        assert_has_key('{DAV:}supported-report-set', props[0][200])

        prop = props[0][200]['{DAV:}supported-report-set']

        assert_kind_of(Dav::Xml::Property::SupportedReportSet, prop)
        value = [
          '{DAV:}sync-collection',
          '{DAV:}expand-property',
          '{DAV:}principal-property-search',
          '{DAV:}principal-search-property-set'
        ]
        assert_equal(value, prop.value)
      end

      def test_calendar_multi_get_report
        body = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data />
  <d:getetag />
</d:prop>
<d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
</c:calendar-multiget>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, 'Invalid HTTP status received. Full response body')

        expected_ical = DatabaseUtil.get_test_calendar_data

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <cal:calendar-data>#{expected_ical}</cal:calendar-data>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_multi_get_report_expand
        body = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20110101T000000Z" end="20111231T235959Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
</c:calendar-multiget>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Invalid HTTP status received. Full response body: #{@response.body_as_string}")

        utc = ActiveSupport::TimeZone.new('UTC')
        expected_ical = DatabaseUtil.get_test_calendar_data
        expected_ical = VObject::Reader.read(expected_ical)
        expected_ical.expand(
          utc.parse('2011-01-01 00:00:00'),
          utc.parse('2011-12-31 23:59:59')
        )
        expected_ical = expected_ical.serialize.gsub("\r\n", "&#13;\n")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <cal:calendar-data>#{expected_ical}</cal:calendar-data>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_query_report
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20000101T000000Z" end="20101231T235959Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")

        utc = ActiveSupport::TimeZone.new('UTC')
        expected_ical = DatabaseUtil.get_test_calendar_data
        expected_ical = VObject::Reader.read(expected_ical)
        expected_ical.expand(
          utc.parse('2000-01-01 00:00:00'),
          utc.parse('2010-12-31 23:59:59')
        )
        expected_ical = expected_ical.serialize.gsub("\r\n", "&#xD;\n")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <cal:calendar-data>#{expected_ical}</cal:calendar-data>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_query_report_windows_phone
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20000101T000000Z" end="20101231T235959Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467',
          'Depth' => '0',
          'User-Agent' => 'MSFT-WP/8.10.14219 (gzip)'
        )

        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")

        utc = ActiveSupport::TimeZone.new('UTC')
        expected_ical = DatabaseUtil.get_test_calendar_data
        expected_ical = VObject::Reader.read(expected_ical)
        expected_ical.expand(
          utc.parse('2000-01-01 00:00:00'),
          utc.parse('2010-12-31 23:59:59')
        )
        expected_ical = expected_ical.serialize.gsub("\r\n", "&#xD;\n")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <cal:calendar-data>#{expected_ical}</cal:calendar-data>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_query_report_bad_depth
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20000101T000000Z" end="20101231T235959Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467',
          'Depth' => '0'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")
      end

      def test_calendar_query_report_no_cal_data
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_query_report_no_filters
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data />
  <d:getetag />
</d:prop>
</c:calendar-query>
XML

        request = Http::Request.new('REPORT', '/calendars/user1/UUID-123467')
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")
      end

      def test_calendar_query_report1_object
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20000101T000000Z" end="20101231T235959Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467/UUID-2345',
          'Depth' => '0'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")

        utc = ActiveSupport::TimeZone.new('UTC')
        expected_ical = DatabaseUtil.get_test_calendar_data
        expected_ical = VObject::Reader.read(expected_ical)
        expected_ical.expand(
          utc.parse('2000-01-01 00:00:00'),
          utc.parse('2010-12-31 23:59:59')
        )
        expected_ical = expected_ical.serialize.gsub("\r\n", "&#xD;\n")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <cal:calendar-data>#{expected_ical}</cal:calendar-data>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_calendar_query_report1_object_no_cal_data
        body = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <d:getetag />
</d:prop>
<c:filter>
  <c:comp-filter name="VCALENDAR">
    <c:comp-filter name="VEVENT" />
  </c:comp-filter>
</c:filter>
</c:calendar-query>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1/UUID-123467/UUID-2345',
          'Depth' => '0'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(207, @response.status, "Received an unexpected status. Full response body: #{@response.body_as_string}")

        expected = <<XML
<?xml version="1.0"?>
<d:multistatus xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:response>
  <d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
  <d:propstat>
    <d:prop>
      <d:getetag>"e207e33c10e5fb9c12cfb35b5d9116e1"</d:getetag>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
</d:response>
</d:multistatus>
XML

        assert_xml_equal(expected, @response.body_as_string)
      end

      def test_html_actions_panel
        output = Box.new('')
        r = @server.emit('onHTMLActionsPanel', [@server.tree.node_for_path('calendars/user1'), output])
        refute(r)

        assert(output.value.index('Display name'))
      end

      def test_calendar_multi_get_report_no_end
        body = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20110101T000000Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
</c:calendar-multiget>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status, "Invalid HTTP status received. Full response body: #{@response.body_as_string}")
      end

      def test_calendar_multi_get_report_no_start
        body = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand end="20110101T000000Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
</c:calendar-multiget>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status, "Invalid HTTP status received. Full response body: #{@response.body_as_string}")
      end

      def test_calendar_multi_get_report_end_before_start
        body = <<XML
<?xml version="1.0"?>
<c:calendar-multiget xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">
<d:prop>
  <c:calendar-data>
     <c:expand start="20200101T000000Z" end="20110101T000000Z" />
  </c:calendar-data>
  <d:getetag />
</d:prop>
<d:href>/calendars/user1/UUID-123467/UUID-2345</d:href>
</c:calendar-multiget>
XML

        request = Http::Request.new(
          'REPORT',
          '/calendars/user1',
          'Depth' => '1'
        )
        request.body = body

        @server.http_request = request
        @server.exec

        assert_equal(400, @response.status, "Invalid HTTP status received. Full response body: #{@response.body_as_string}")
      end

      def test_calendar_properties
        ns = '{urn:ietf:params:xml:ns:caldav}'
        props = @server.properties(
          'calendars/user1/UUID-123467',
          [
            ns + 'max-resource-size',
            ns + 'supported-calendar-data',
            ns + 'supported-collation-set'
          ]
        )

        assert_instance_equal(
          {
            ns + 'max-resource-size'       => 10_000_000,
            ns + 'supported-calendar-data' => Xml::Property::SupportedCalendarData.new,
            ns + 'supported-collation-set' => Xml::Property::SupportedCollationSet.new
          },
          props
        )
      end
    end
  end
end
