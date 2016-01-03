require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class SupportedCalendarDataTest < Dav::Xml::XmlTester
          def test_simple
            sccs = SupportedCalendarData.new
            assert_kind_of(SupportedCalendarData, sccs)
          end

          def test_serialize
            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            property = SupportedCalendarData.new

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}">
  <cal:calendar-data content-type="text/calendar" version="2.0"/>
  <cal:calendar-data content-type="application/calendar+json"/>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
