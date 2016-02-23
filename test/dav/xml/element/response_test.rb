require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Element
        class ResponseTest < XmlTester
          def test_simple
            inner_props = {
              200 => { '{DAV:}displayname' => 'my file' },
              404 => { '{DAV:}owner' => nil }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)

            assert_equal('uri', property.href)
            assert_equal(inner_props, property.response_properties)
          end

          def test_serialize
            inner_props = {
              200 => { '{DAV:}displayname' => 'my file' },
              404 => { '{DAV:}owner' => nil }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)

            xml = write('{DAV:}root' => { '{DAV:}response' => property })

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:response>
    <d:href>/uri</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>my file</d:displayname>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
    <d:propstat>
      <d:prop>
        <d:owner/>
      </d:prop>
      <d:status>HTTP/1.1 404 Not Found</d:status>
    </d:propstat>
  </d:response>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

          # This one is specifically for testing properties with no namespaces, which is legal xml
          def test_serialize_empty_namespace
            inner_props = {
              200 => { '{}propertyname' => 'value' }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)

            xml = write('{DAV:}root' => { '{DAV:}response' => property })
            expected = <<XML
<d:root xmlns:d="DAV:">
  <d:response>
  <d:href>/uri</d:href>
  <d:propstat>
    <d:prop>
      <propertyname xmlns="">value</propertyname>
    </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
  </d:propstat>
  </d:response>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          # This one is specifically for testing properties with no namespaces, which is legal xml
          def test_serialize_custom_namespace
            inner_props = {
              200 => { '{http://sabredav.org/NS/example}propertyname' => 'value' }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)
            xml = write('{DAV:}root' => { '{DAV:}response' => property })

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:response>
    <d:href>/uri</d:href>
    <d:propstat>
      <d:prop>
        <x1:propertyname xmlns:x1="http://sabredav.org/NS/example">value</x1:propertyname>
      </d:prop>
    <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

          def test_serialize_complex_property
            inner_props = {
              200 => { '{DAV:}link' => Tilia::Dav::Xml::Property::Href.new('http://sabredav.org/', false) }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)
            xml = write('{DAV:}root' => { '{DAV:}response' => property })
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:response>
    <d:href>/uri</d:href>
    <d:propstat>
      <d:prop>
        <d:link><d:href>http://sabredav.org/</d:href></d:link>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

          def test_serialize_break
            inner_props = {
              200 => { '{DAV:}link' => Class.new }
            }

            property = Tilia::Dav::Xml::Element::Response.new('uri', inner_props)
            assert_raises(ArgumentError) { write('{DAV:}root' => { '{DAV:}response' => property }) }
          end

          def test_deserialize_complex_property
            xml = <<XML
<?xml version="1.0"?>
<d:response xmlns:d="DAV:">
<d:href>/uri</d:href>
<d:propstat>
  <d:prop>
    <d:foo>hello</d:foo>
  </d:prop>
  <d:status>HTTP/1.1 200 OK</d:status>
</d:propstat>
</d:response>
XML

            result = parse(
              xml,
              '{DAV:}response' => Tilia::Dav::Xml::Element::Response,
              '{DAV:}foo' => lambda do |reader|
                reader.next
                return 'world'
              end
            )
            expected = Tilia::Dav::Xml::Element::Response.new(
              '/uri',
              '200' => { '{DAV:}foo' => 'world' }
            )

            assert_instance_equal(expected, result['value'])
          end

          def test_serialize_urlencoding
            inner_props = {
              200 => {
                '{DAV:}displayname' => 'my file',
              }
            }

            property = Response.new('space here', inner_props)

            xml = write('{DAV:}root' => {'{DAV:}response' => property})
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:response>
    <d:href>/space%20here</d:href>
    <d:propstat>
      <d:prop>
        <d:displayname>my file</d:displayname>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

          # The WebDAV spec _requires_ at least one DAV:propstat to appear for
          # every DAV:response. In some circumstances however, there are no
          # properties to encode.
          #
          # In those cases we MUST specify at least one DAV:propstat anyway, with
          # no properties.
          def test_serialize_no_properties

        inner_props = []

            property = Response.new('uri', inner_props)

            xml = write('{DAV:}root' => { '{DAV:}response' => property})
            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:response>
      <d:href>/uri</d:href>
      <d:propstat>
        <d:prop />
        <d:status>HTTP/1.1 418 I\'m a teapot</d:status>
      </d:propstat>
  </d:response>
</d:root>
XML
            assert_xml_equal(expected, xml)
          end

           # In the case of {DAV:}prop, a deserializer should never get called, if
          # the property element is empty.
          def test_deserialize_complex_property_empty
            xml = <<XML
<?xml version="1.0"?>
<d:response xmlns:d="DAV:">
  <d:href>/uri</d:href>
  <d:propstat>
    <d:prop>
      <d:foo />
    </d:prop>
    <d:status>HTTP/1.1 404 Not Found</d:status>
  </d:propstat>
</d:response>
XML

            result = parse(
              xml,
              '{DAV:}response' => Tilia::Dav::Xml::Element::Response,
              '{DAV:}foo' => lambda do |_reader|
                fail 'This should never happen'
              end
            )
            expected = Tilia::Dav::Xml::Element::Response.new(
              '/uri',
              '404' => { '{DAV:}foo' => nil }
            )

            assert_instance_equal(expected, result['value'])
          end
        end
      end
    end
  end
end
