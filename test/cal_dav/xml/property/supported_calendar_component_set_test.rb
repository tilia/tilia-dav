require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class AllowedSharingModesTest < Dav::Xml::XmlTester
          def setup
            super
            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            @namespace_map[Plugin::NS_CALENDARSERVER] = 'cs'
          end

          def test_simple
            prop = SupportedCalendarComponentSet.new(['VEVENT'])
            assert_equal(['VEVENT'], prop.value)
          end

          def test_multiple
            prop = SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
            assert_equal(['VEVENT', 'VTODO'], prop.value)
          end

          def test_serialize
            property = SupportedCalendarComponentSet.new(['VEVENT', 'VTODO'])
            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cal:comp name="VEVENT"/>
  <cal:comp name="VTODO"/>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
   <cal:comp name="VEVENT"/>
   <cal:comp name="VTODO"/>
</d:root>
XML

            result = parse(
              xml,
              '{DAV:}root' => SupportedCalendarComponentSet
            )

            assert_instance_equal(
              SupportedCalendarComponentSet.new(['VEVENT', 'VTODO']),
              result['value']
            )
          end

          def test_unserialize_empty
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
</d:root>
XML

            assert_raises(Tilia::Xml::ParseException) do
              parse(
                xml,
                '{DAV:}root' => SupportedCalendarComponentSet
              )
            end
          end
        end
      end
    end
  end
end
