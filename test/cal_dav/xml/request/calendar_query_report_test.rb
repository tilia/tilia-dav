require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Request
        class CalendarQueryReportTest < Dav::Xml::XmlTester
          def setup
            super
            @element_map['{urn:ietf:params:xml:ns:caldav}calendar-query'] = CalendarQueryReport
          end

          def test_deserialize
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

            result = parse(xml)
            calendar_query_report = CalendarQueryReport.new
            calendar_query_report.properties = ['{DAV:}getetag']
            calendar_query_report.filters = {
              'name'           => 'VCALENDAR',
              'is-not-defined' => false,
              'comp-filters'   => [],
              'prop-filters'   => [],
              'time-range'     => false
            }

            assert_instance_equal(calendar_query_report, result['value'])
          end

          def test_deserialize_no_filter
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
    </d:prop>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_complex
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data content-type="application/json+calendar" version="2.0">
            <c:expand start="20150101T000000Z" end="20160101T000000Z" />
      </c:calendar-data>
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR">
            <c:comp-filter name="VEVENT">
                <c:time-range start="20150101T000000Z" end="20160101T000000Z" />
                <c:prop-filter name="UID" />
                <c:comp-filter name="VALARM">
                    <c:is-not-defined />
                </c:comp-filter>
                <c:prop-filter name="X-PROP">
                    <c:param-filter name="X-PARAM" />
                    <c:param-filter name="X-PARAM2">
                        <c:is-not-defined />
                    </c:param-filter>
                    <c:param-filter name="X-PARAM3">
                        <c:text-match negate-condition="yes">hi</c:text-match>
                    </c:param-filter>
                </c:prop-filter>
                <c:prop-filter name="X-PROP2">
                    <c:is-not-defined />
                </c:prop-filter>
                <c:prop-filter name="X-PROP3">
                    <c:time-range start="20150101T000000Z" end="20160101T000000Z" />
                </c:prop-filter>
                <c:prop-filter name="X-PROP4">
                    <c:text-match>Hello</c:text-match>
                </c:prop-filter>
            </c:comp-filter>
        </c:comp-filter>
    </c:filter>
</c:calendar-query>
XML

            result = parse(xml)
            calendar_query_report = CalendarQueryReport.new
            calendar_query_report.version = '2.0'
            calendar_query_report.content_type = 'application/json+calendar'
            calendar_query_report.properties = [
              '{DAV:}getetag',
              '{urn:ietf:params:xml:ns:caldav}calendar-data'
            ]
            utc = ActiveSupport::TimeZone.new('UTC')
            calendar_query_report.expand = {
              'start' => utc.parse('2015-01-01 00:00:00'),
              'end'   => utc.parse('2016-01-01 00:00:00')
            }
            calendar_query_report.filters = {
              'name'           => 'VCALENDAR',
              'is-not-defined' => false,
              'comp-filters'   => [
                {
                  'name'           => 'VEVENT',
                  'is-not-defined' => false,
                  'comp-filters'   => [
                    {
                      'name'           => 'VALARM',
                      'is-not-defined' => true,
                      'comp-filters'   => [],
                      'prop-filters'   => [],
                      'time-range'     => false
                    }
                  ],
                  'prop-filters' => [
                    {
                      'name'           => 'UID',
                      'is-not-defined' => false,
                      'time-range'     => false,
                      'text-match'     => nil,
                      'param-filters'  => []
                    },
                    {
                      'name'           => 'X-PROP',
                      'is-not-defined' => false,
                      'time-range'     => false,
                      'text-match'     => nil,
                      'param-filters'  => [
                        {
                          'name'           => 'X-PARAM',
                          'is-not-defined' => false,
                          'text-match'     => nil
                        },
                        {
                          'name'           => 'X-PARAM2',
                          'is-not-defined' => true,
                          'text-match'     => nil
                        },
                        {
                          'name'           => 'X-PARAM3',
                          'is-not-defined' => false,
                          'text-match'     => {
                            'negate-condition' => true,
                            'collation'        => 'i;ascii-casemap',
                            'value'            => 'hi'
                          }
                        }
                      ]
                    },
                    {
                      'name'           => 'X-PROP2',
                      'is-not-defined' => true,
                      'time-range'     => false,
                      'text-match'     => nil,
                      'param-filters'  => []
                    },
                    {
                      'name'           => 'X-PROP3',
                      'is-not-defined' => false,
                      'time-range'     => {
                        'start' => utc.parse('2015-01-01 00:00:00'),
                        'end'   => utc.parse('2016-01-01 00:00:00')
                      },
                      'text-match'    => nil,
                      'param-filters' => []
                    },
                    {
                      'name'           => 'X-PROP4',
                      'is-not-defined' => false,
                      'time-range'     => false,
                      'text-match'     => {
                        'negate-condition' => false,
                        'collation'        => 'i;ascii-casemap',
                        'value'            => 'Hello'
                      },
                      'param-filters' => []
                    }
                  ],
                  'time-range' => {
                    'start' => utc.parse('2015-01-01 00:00:00'),
                    'end'   => utc.parse('2016-01-01 00:00:00')
                  }
                }
              ],
              'prop-filters' => [],
              'time-range'   => false
            }

            assert_instance_equal(calendar_query_report, result['value'])
          end

          def test_deserialize_double_top_comp_filter
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data content-type="application/json+calendar" version="2.0">
            <c:expand start="20150101T000000Z" end="20160101T000000Z" />
      </c:calendar-data>
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_missing_expand_end
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data content-type="application/json+calendar" version="2.0">
            <c:expand start="20150101T000000Z" />
      </c:calendar-data>
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_expand_end_before_start
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data content-type="application/json+calendar" version="2.0">
            <c:expand start="20150101T000000Z" end="20140101T000000Z" />
      </c:calendar-data>
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR" />
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_time_range_on_vcalendar
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR">
            <c:time-range start="20150101T000000Z" end="20160101T000000Z" />
        </c:comp-filter>
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_time_range_end_before_start
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR">
            <c:comp-filter name="VEVENT">
                <c:time-range start="20150101T000000Z" end="20140101T000000Z" />
            </c:comp-filter>
        </c:comp-filter>
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end

          def test_deserialize_time_range_prop_end_before_start
            xml = <<XML
<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
    <d:prop>
      <d:getetag />
      <c:calendar-data />
    </d:prop>
    <c:filter>
        <c:comp-filter name="VCALENDAR">
            <c:comp-filter name="VEVENT">
                <c:prop-filter name="DTSTART">
                    <c:time-range start="20150101T000000Z" end="20140101T000000Z" />
                </c:prop-filter>
            </c:comp-filter>
        </c:comp-filter>
    </c:filter>
</c:calendar-query>
XML

            assert_raises(Dav::Exception::BadRequest) do
              parse(xml)
            end
          end
        end
      end
    end
  end
end
