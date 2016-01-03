require 'test_helper'

module Tilia
  module DavAcl
    module Xml
      module Property
        class PrincipalTest < Minitest::Test
          def test_simple
            principal = Principal.new(Principal::UNAUTHENTICATED)
            assert_equal(Principal::UNAUTHENTICATED, principal.type)
            assert_nil(principal.href)

            principal = Principal.new(Principal::AUTHENTICATED)
            assert_equal(Principal::AUTHENTICATED, principal.type)
            assert_nil(principal.href)

            principal = Principal.new(Principal::HREF, 'admin')
            assert_equal(Principal::HREF, principal.type)
            assert_equal('admin/', principal.href)
          end

          def test_no_href
            assert_raises(Dav::Exception) { Principal.new(Principal::HREF) }
          end

          def test_serialize_un_authenticated
            prin = Principal.new(Principal::UNAUTHENTICATED)

            xml = Dav::ServerMock.new.xml.write('{DAV:}principal', prin)
            expected = <<XML
<d:principal xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:unauthenticated/>
</d:principal>
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize_authenticated
            prin = Principal.new(Principal::AUTHENTICATED)
            xml = Dav::ServerMock.new.xml.write('{DAV:}principal', prin)

            expected = <<XML
<d:principal xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:authenticated/>
</d:principal>
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize_href
            prin = Principal.new(Principal::HREF, 'principals/admin')
            xml = Dav::ServerMock.new.xml.write('{DAV:}principal', prin, '/')

            expected = <<XML
<d:principal xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
<d:href>/principals/admin/</d:href>
</d:principal>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize_href
            xml = <<XML
<?xml version="1.0"?>
<d:principal xmlns:d="DAV:">
<d:href>/principals/admin</d:href>
</d:principal>
XML

            principal = parse(xml)
            assert_equal(Principal::HREF, principal.type)
            assert_equal('/principals/admin/', principal.href)
          end

          def test_unserialize_authenticated
            xml = <<XML
<?xml version="1.0"?>
<d:principal xmlns:d="DAV:">
  <d:authenticated />
</d:principal>
XML

            principal = parse(xml)
            assert_equal(Principal::AUTHENTICATED, principal.type)
          end

          def test_unserialize_unauthenticated
            xml = <<XML
<?xml version="1.0"?>
<d:principal xmlns:d="DAV:">
  <d:unauthenticated />
</d:principal>
XML

            principal = parse(xml)
            assert_equal(Principal::UNAUTHENTICATED, principal.type)
          end

          def test_unserialize_unknown
            xml = <<XML
<?xml version="1.0"?>
<d:principal xmlns:d="DAV:">
  <d:foo />
</d:principal>
XML

            assert_raises(Dav::Exception::BadRequest) { parse(xml) }
          end

          def parse(xml)
            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}principal'] = Tilia::DavAcl::Xml::Property::Principal
            reader.xml(xml)
            result = reader.parse
            result['value']
          end

          def test_to_html
            html_provider.each do |v|
              (principal, output) = v

              html = principal.to_html(Dav::Browser::HtmlOutputHelper.new('/', {}))

              assert_xml_equal(output, html)
            end
          end

          # Provides data for the html tests
          #
          # @return array
          def html_provider
            [
              [
                Principal.new(Principal::UNAUTHENTICATED),
                '<em>unauthenticated</em>'
              ],
              [
                Principal.new(Principal::AUTHENTICATED),
                '<em>authenticated</em>'
              ],
              [
                Principal.new(Principal::ALL),
                '<em>all</em>'
              ],
              [
                Principal.new(Principal::HREF, 'principals/admin'),
                '<a href="/principals/admin/">/principals/admin/</a>'
              ]
            ]
          end
        end
      end
    end
  end
end
