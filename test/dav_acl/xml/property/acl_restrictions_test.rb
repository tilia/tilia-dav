require 'test_helper'

module Tilia
  module DavAcl
    module Xml
      module Property
        class AclRestrictionsTest < Minitest::Test
          def test_construct
            prop = AclRestrictions.new
            assert_kind_of(Tilia::DavAcl::Xml::Property::AclRestrictions, prop)
          end

          def test_serialize
            prop = AclRestrictions.new
            xml = Dav::ServerMock.new.xml.write('{DAV:}root', prop)

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns"><d:grant-only/><d:no-invert/></d:root>'
XML

            assert_xml_equal(expected, xml)
          end
        end
      end
    end
  end
end
