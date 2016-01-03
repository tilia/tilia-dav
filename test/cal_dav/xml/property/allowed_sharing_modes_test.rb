require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class AllowedSharingModesTest < Dav::Xml::XmlTester
          def test_simple
            sccs = AllowedSharingModes.new(true, true)
            assert_kind_of(AllowedSharingModes, sccs)
          end

          def test_serialize
            property = AllowedSharingModes.new(true, true)

            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            @namespace_map[Plugin::NS_CALENDARSERVER] = 'cs'

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cs:can-be-shared/>
  <cs:can-be-published/>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
