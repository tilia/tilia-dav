require 'test_helper'

module Tilia
  module CardDav
    module Xml
      module Property
        class SupportedCollationSetTest < Dav::Xml::XmlTester
          def test_simple
            property = SupportedCollationSet.new
            assert_kind_of(SupportedCollationSet, property)
          end

          def test_serialize
            property = SupportedCollationSet.new

            @namespace_map[Plugin::NS_CARDDAV] = 'card'

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:card="#{Plugin::NS_CARDDAV}" xmlns:d="DAV:">
<card:supported-collation>i;ascii-casemap</card:supported-collation>
<card:supported-collation>i;octet</card:supported-collation>
<card:supported-collation>i;unicode-casemap</card:supported-collation>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
