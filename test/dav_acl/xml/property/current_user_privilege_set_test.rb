require 'test_helper'

module Tilia
  module DavAcl
    module Xml
      module Property
        class CurrentUserPrivilegeSetTest < Minitest::Test
          def test_serialize
            privileges = [
              '{DAV:}read',
              '{DAV:}write'
            ]
            prop = CurrentUserPrivilegeSet.new(privileges)
            xml = Dav::ServerMock.new.xml.write('{DAV:}root', prop)

            expected = <<XML
<d:root xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
  <d:privilege>
    <d:read />
  </d:privilege>
  <d:privilege>
    <d:write />
  </d:privilege>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize
            source = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:privilege>
    <d:write-properties />
  </d:privilege>
  <d:ignoreme />
  <d:privilege>
    <d:read />
  </d:privilege>
</d:root>
XML

            result = parse(source)
            assert(result.has('{DAV:}read'))
            assert(result.has('{DAV:}write-properties'))
            refute(result.has('{DAV:}bind'))
          end

          def parse(xml)
            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}root'] = Tilia::DavAcl::Xml::Property::CurrentUserPrivilegeSet
            reader.xml(xml)
            result = reader.parse
            result['value']
          end

          def test_to_html
            privileges = ['{DAV:}read', '{DAV:}write']

            prop = CurrentUserPrivilegeSet.new(privileges)
            html = Dav::Browser::HtmlOutputHelper.new(
              '/base/',
              'DAV:' => 'd'
            )

            expected =
              '<span title="{DAV:}read">d:read</span>, ' \
              '<span title="{DAV:}write">d:write</span>'

            assert_equal(expected, prop.to_html(html))
          end
        end
      end
    end
  end
end
