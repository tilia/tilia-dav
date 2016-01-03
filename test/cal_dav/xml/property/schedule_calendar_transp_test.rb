
require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class ScheduleCalendarTranspTest < Dav::Xml::XmlTester
          def setup
            super
            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            @namespace_map[Plugin::NS_CALENDARSERVER] = 'cs'
          end

          def test_simple
            prop = ScheduleCalendarTransp.new(ScheduleCalendarTransp::OPAQUE)
            assert_equal(
              ScheduleCalendarTransp::OPAQUE,
              prop.value
            )
          end

          def test_bad_value
            assert_raises(ArgumentError) do
              ScheduleCalendarTransp.new('ahhh')
            end
          end

          def test_serialize_opaque
            property = ScheduleCalendarTransp.new(ScheduleCalendarTransp::OPAQUE)
            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cal:opaque />
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize_transparent
            property = ScheduleCalendarTransp.new(ScheduleCalendarTransp::TRANSPARENT)
            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cal:transparent />
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize_transparent
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cal:transparent />
</d:root>
XML

            result = parse(
              xml,
              '{DAV:}root' => ScheduleCalendarTransp
            )

            assert_instance_equal(
              ScheduleCalendarTransp.new(ScheduleCalendarTransp::TRANSPARENT),
              result['value']
            )
          end

          def test_unserialize_opaque
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cal:opaque />
</d:root>
XML

            result = parse(
              xml,
              '{DAV:}root' => ScheduleCalendarTransp
            )

            assert_instance_equal(
              ScheduleCalendarTransp.new(ScheduleCalendarTransp::OPAQUE),
              result['value']
            )
          end
        end
      end
    end
  end
end
