require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Request
        class PropPatchTest < XmlTester
          def test_serialize
            prop_patch = Tilia::Dav::Xml::Request::PropPatch.new
            prop_patch.properties = {
              '{DAV:}displayname' => 'Hello!',
              '{DAV:}delete-me'   => nil,
              '{DAV:}some-url'    => Tilia::Dav::Xml::Property::Href.new('foo/bar')
            }

            result = write('{DAV:}propertyupdate' => prop_patch)

            expected = <<XML
<?xml version="1.0"?>
<d:propertyupdate xmlns:d="DAV:">
  <d:set>
    <d:prop>
      <d:displayname>Hello!</d:displayname>
    </d:prop>
  </d:set>
  <d:remove>
    <d:prop>
      <d:delete-me />
    </d:prop>
  </d:remove>
  <d:set>
    <d:prop>
      <d:some-url>
        <d:href>/foo/bar</d:href>
      </d:some-url>
    </d:prop>
  </d:set>
</d:propertyupdate>
XML

            assert_xml_equal(expected, result)
          end
        end
      end
    end
  end
end
