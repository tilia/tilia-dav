require 'test_helper'

module Tilia
  module CardDav
    module Xml
      module Property
        class SupportedAddressDataDataTest < Dav::Xml::XmlTester
          def test_simple
            property = SupportedAddressData.new
            assert_kind_of(SupportedAddressData, property)
          end

          def test_serialize
            property = SupportedAddressData.new

            @namespace_map[Plugin::NS_CARDDAV] = 'card'

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:card="#{Plugin::NS_CARDDAV}" xmlns:d="DAV:">
  <card:address-data-type content-type="text/vcard" version="3.0"/>
  <card:address-data-type content-type="text/vcard" version="4.0"/>
  <card:address-data-type content-type="application/vcard+json" version="4.0"/>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
