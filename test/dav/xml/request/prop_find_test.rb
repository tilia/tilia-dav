require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Request
        class PropFindTest < XmlTester
          def test_deserialize_prop
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:prop>
    <d:hello />
  </d:prop>
</d:root>
XML

            result = parse(xml, '{DAV:}root' => Tilia::Dav::Xml::Request::PropFind)

            prop_find = Tilia::Dav::Xml::Request::PropFind.new
            prop_find.properties = ['{DAV:}hello']

            assert_instance_equal(prop_find, result['value'])
          end

          def test_deserialize_all_prop
            xml = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:allprop />
</d:root>
XML

            result = parse(xml, '{DAV:}root' => Tilia::Dav::Xml::Request::PropFind)

            prop_find = Tilia::Dav::Xml::Request::PropFind.new
            prop_find.all_prop = true

            assert_instance_equal(prop_find, result['value'])
          end
        end
      end
    end
  end
end
