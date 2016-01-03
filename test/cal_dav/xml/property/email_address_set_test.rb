require 'test_helper'

module Tilia
  module CalDav
    module Xml
      module Property
        class EmailAddressSetTest < Dav::Xml::XmlTester
          def setup
            super
            @namespace_map[Plugin::NS_CALENDARSERVER] = 'cs'
          end

          def test_simple
            eas = EmailAddressSet.new(['foo@example.org'])
            assert_equal(['foo@example.org'], eas.value)
          end

          def test_serialize
            property = EmailAddressSet.new(['foo@example.org'])

            xml = write('{DAV:}root' => property)
            expected = <<XML
<?xml version="1.0"?>
  <d:root xmlns:d="DAV:" xmlns:cs="#{Plugin::NS_CALENDARSERVER}">
  <cs:email-address>foo@example.org</cs:email-address>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
