require 'test_helper'

module Tilia
  module DavAcl
    module Xml
      module Property
        class SupportedPrivilegeSetTest < Minitest::Test
          def test_simple
            prop = SupportedPrivilegeSet.new(
              'privilege' => '{DAV:}all'
            )
            assert_kind_of(Tilia::DavAcl::Xml::Property::SupportedPrivilegeSet, prop)
          end

          def test_serialize_simple
            prop = SupportedPrivilegeSet.new(
              'privilege' => '{DAV:}all'
            )

            xml = Dav::ServerMock.new.xml.write('{DAV:}supported-privilege-set', prop)
            expected = <<XML
<d:supported-privilege-set xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
  <d:supported-privilege>
    <d:privilege>
      <d:all/>
    </d:privilege>
  </d:supported-privilege>
</d:supported-privilege-set>
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize_aggregate
            prop = SupportedPrivilegeSet.new(
              'privilege'  => '{DAV:}all',
              'abstract'   => true,
              'aggregates' => [
                {
                  'privilege' => '{DAV:}read'
                },
                {
                  'privilege'   => '{DAV:}write',
                  'description' => 'booh'
                }
              ]
            )

            xml = Dav::ServerMock.new.xml.write('{DAV:}supported-privilege-set', prop)
            expected = <<XML
<d:supported-privilege-set xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
 <d:supported-privilege>
  <d:privilege>
   <d:all/>
  </d:privilege>
  <d:abstract/>
  <d:supported-privilege>
   <d:privilege>
    <d:read/>
   </d:privilege>
  </d:supported-privilege>
  <d:supported-privilege>
   <d:privilege>
    <d:write/>
   </d:privilege>
  <d:description>booh</d:description>
  </d:supported-privilege>
 </d:supported-privilege>
</d:supported-privilege-set>
XML

            assert_xml_equal(expected, xml)
          end

          def test_to_html
            prop = SupportedPrivilegeSet.new(
              'privilege'  => '{DAV:}all',
              'abstract'   => true,
              'aggregates' => [
                {
                  'privilege' => '{DAV:}read'
                },
                {
                  'privilege'   => '{DAV:}write',
                  'description' => 'booh'
                }
              ]
            )
            html = Dav::Browser::HtmlOutputHelper.new(
              '/base/',
              'DAV:' => 'd'
            )

            expected = <<HTML
<ul class="tree"><li><span title="{DAV:}all">d:all</span> <i>(abstract)</i>
<ul>
<li><span title="{DAV:}read">d:read</span></li>
<li><span title="{DAV:}write">d:write</span> booh</li>
</ul></li>
</ul>
HTML

            assert_equal(expected, prop.to_html(html))
          end
        end
      end
    end
  end
end
