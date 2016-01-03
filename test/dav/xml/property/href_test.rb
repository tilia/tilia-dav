require 'test_helper'

module Tilia
  module Dav
    module Xml
      module Property
        class HrefTest < XmlTester
          def test_construct
            href = Tilia::Dav::Xml::Property::Href.new('path')
            assert_equal('path', href.href)
          end

          def test_serialize
            href = Tilia::Dav::Xml::Property::Href.new('path')
            assert_equal('path', href.href)

            self.context_uri = '/bla/'

            xml = write('{DAV:}anything' => href)
            expected = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"><d:href>/bla/path</d:href></d:anything>
XML
            assert_xml_equal(expected, xml)
          end

          def test_serialize_no_prefix
            href = Tilia::Dav::Xml::Property::Href.new('path', false)
            assert_equal('path', href.href)

            xml = write('{DAV:}anything' => href)
            expected = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"><d:href>path</d:href></d:anything>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize
            xml = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"><d:href>/bla/path</d:href></d:anything>
XML

            result = parse(xml, '{DAV:}anything' => Tilia::Dav::Xml::Property::Href)

            href = result['value']

            assert_kind_of(Tilia::Dav::Xml::Property::Href, href)

            assert_equal('/bla/path', href.href)
          end

          def test_unserialize_incompatible
            xml = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"><d:href2>/bla/path</d:href2></d:anything>
XML
            result = parse(xml, '{DAV:}anything' => Tilia::Dav::Xml::Property::Href)
            href = result['value']
            assert_nil(href)
          end

          def test_unserialize_empty
            xml = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"></d:anything>
XML
            result = parse(xml, '{DAV:}anything' => Tilia::Dav::Xml::Property::Href)
            href = result['value']
            assert_nil(href)
          end

          # This method tests if hrefs containing & are correctly encoded.
          def test_serialize_entity
            href = Tilia::Dav::Xml::Property::Href.new('http://example.org/?a&b', false)
            assert_equal('http://example.org/?a&b', href.href)

            xml = write('{DAV:}anything' => href)
            expected = <<XML
<?xml version="1.0"?>
<d:anything xmlns:d="DAV:"><d:href>http://example.org/?a&amp;b</d:href></d:anything>
XML
            assert_xml_equal(expected, xml)
          end

          def test_to_html
            href = Tilia::Dav::Xml::Property::Href.new(
              [
                '/foo/bar',
                'foo/bar',
                'http://example.org/bar'
              ]
            )

            html = Tilia::Dav::Browser::HtmlOutputHelper.new(
              '/base/',
              {}
            )

            expected = '<a href="/foo/bar">/foo/bar</a><br />'
            expected << '<a href="/base/foo/bar">/base/foo/bar</a><br />'
            expected << '<a href="http://example.org/bar">http://example.org/bar</a>'

            assert_equal(expected, href.to_html(html))
          end
        end
      end
    end
  end
end
