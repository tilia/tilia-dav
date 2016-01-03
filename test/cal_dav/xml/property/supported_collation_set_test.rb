require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class SupportedCollationSetTest < Dav::Xml::XmlTester
          def test_simple
            scs = SupportedCollationSet.new
            assert_kind_of(SupportedCollationSet, scs)
          end

          def test_serialize
            property = SupportedCollationSet.new

            @namespace_map[Plugin::NS_CALDAV] = 'cal'
            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:cal="#{Plugin::NS_CALDAV}">
  <cal:supported-collation>i;ascii-casemap</cal:supported-collation>
  <cal:supported-collation>i;octet</cal:supported-collation>
  <cal:supported-collation>i;unicode-casemap</cal:supported-collation>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
