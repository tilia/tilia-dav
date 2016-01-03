require 'test_helper'

module Tilia
  module DavAcl
    module Xml
      module Property
        class AclTest < Minitest::Test
          def test_construct
            acl = Acl.new([])
            assert_kind_of(Tilia::DavAcl::Xml::Property::Acl, acl)
          end

          def test_serialize_empty
            acl = Acl.new([])
            xml = Dav::ServerMock.new.xml.write('{DAV:}root', acl)

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns" />
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize
            privileges = [
              {
                'principal' => 'principals/evert',
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => 'principals/foo',
                'privilege' => '{DAV:}read',
                'protected' => true
              }
            ]

            acl = Acl.new(privileges)
            xml = Dav::ServerMock.new.xml.write('{DAV:}root', acl, '/')

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
  <d:ace>
    <d:principal>
      <d:href>/principals/evert/</d:href>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
  <d:ace>
    <d:principal>
      <d:href>/principals/foo/</d:href>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:read/>
      </d:privilege>
    </d:grant>
    <d:protected/>
  </d:ace>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_serialize_special_principals
            privileges = [
              {
                'principal' => '{DAV:}authenticated',
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => '{DAV:}unauthenticated',
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => '{DAV:}all',
                'privilege' => '{DAV:}write'
              }
            ]

            acl = Acl.new(privileges)
            xml = Dav::ServerMock.new.xml.write('{DAV:}root', acl, '/')

            expected = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
  <d:ace>
    <d:principal>
      <d:authenticated/>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
  <d:ace>
    <d:principal>
      <d:unauthenticated/>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
  <d:ace>
    <d:principal>
      <d:all/>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
</d:root>
XML

            assert_xml_equal(expected, xml)
          end

          def test_unserialize
            source = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:ace>
    <d:principal>
      <d:href>/principals/evert/</d:href>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
  <d:ace>
    <d:principal>
      <d:href>/principals/foo/</d:href>
    </d:principal>
    <d:grant>
      <d:privilege>
        <d:read/>
      </d:privilege>
    </d:grant>
    <d:protected/>
  </d:ace>
</d:root>
XML

            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}root'] = Tilia::DavAcl::Xml::Property::Acl
            reader.xml(source)

            result = reader.parse
            result = result['value']

            assert_kind_of(Tilia::DavAcl::Xml::Property::Acl, result)

            expected = [
              {
                'principal' => '/principals/evert/',
                'protected' => false,
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => '/principals/foo/',
                'protected' => true,
                'privilege' => '{DAV:}read'
              }
            ]

            assert_equal(expected, result.privileges)
          end

          def test_unserialize_no_principal
            source = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:ace>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
  </d:ace>
</d:root>
XML

            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}root'] = Tilia::DavAcl::Xml::Property::Acl
            reader.xml(source)

            assert_raises(Dav::Exception::BadRequest) { reader.parse }
          end

          def test_unserialize_other_principal
            source = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:ace>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
    <d:principal><d:authenticated /></d:principal>
  </d:ace>
  <d:ace>
    <d:grant>
      <d:ignoreme />
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
    <d:principal><d:unauthenticated /></d:principal>
  </d:ace>
  <d:ace>
    <d:grant>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:grant>
    <d:principal><d:all /></d:principal>
  </d:ace>
</d:root>
XML

            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}root'] = Tilia::DavAcl::Xml::Property::Acl
            reader.xml(source)

            result = reader.parse
            result = result['value']

            assert_kind_of(Tilia::DavAcl::Xml::Property::Acl, result)

            expected = [
              {
                'principal' => '{DAV:}authenticated',
                'protected' => false,
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => '{DAV:}unauthenticated',
                'protected' => false,
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => '{DAV:}all',
                'protected' => false,
                'privilege' => '{DAV:}write'
              }
            ]

            assert_equal(expected, result.privileges)
          end

          def test_unserialize_deny
            source = <<XML
<?xml version="1.0"?>
<d:root xmlns:d="DAV:">
  <d:ignore-me />
  <d:ace>
    <d:deny>
      <d:privilege>
        <d:write/>
      </d:privilege>
    </d:deny>
    <d:principal><d:href>/principals/evert</d:href></d:principal>
  </d:ace>
</d:root>
XML

            reader = Tilia::Xml::Reader.new
            reader.element_map['{DAV:}root'] = Tilia::DavAcl::Xml::Property::Acl
            reader.xml(source)

            assert_raises(Dav::Exception::NotImplemented) { reader.parse }
          end

          def test_to_html
            privileges = [
              {
                'principal' => 'principals/evert',
                'privilege' => '{DAV:}write'
              },
              {
                'principal' => 'principals/foo',
                'privilege' => '{http://example.org/ns}read',
                'protected' => true
              },
              {
                'principal' => '{DAV:}authenticated',
                'privilege' => '{DAV:}write'
              }
            ]

            acl = Acl.new(privileges)
            html = Dav::Browser::HtmlOutputHelper.new(
              '/base/',
              'DAV:' => 'd'
            )

            expected =
              '<table>' \
              '<tr><th>Principal</th><th>Privilege</th><th></th></tr>' \
              '<tr><td><a href="/base/principals/evert">/base/principals/evert</a></td><td><span title="{DAV:}write">d:write</span></td><td></td></tr>' \
              '<tr><td><a href="/base/principals/foo">/base/principals/foo</a></td><td><span title="{http://example.org/ns}read">{http://example.org/ns}read</span></td><td>(protected)</td></tr>' \
              '<tr><td><span title="{DAV:}authenticated">d:authenticated</span></td><td><span title="{DAV:}write">d:write</span></td><td></td></tr>' \
              '</table>'

            assert_equal(expected, acl.to_html(html))
          end
        end
      end
    end
  end
end
