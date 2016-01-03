require 'test_helper'

module Tilia
  module CardDav
    module Xml
      module Request
        class AddressBookQueryReportTest < Dav::Xml::XmlTester
          def setup
            super
            @element_map['{urn:ietf:params:xml:ns:carddav}addressbook-query'] = AddressBookQueryReport
          end

          def test_deserialize
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter>
    <c:prop-filter name="uid" />
  </c:filter>
</c:addressbook-query>
XML

            result = parse(xml)
            address_book_query_report = AddressBookQueryReport.new
            address_book_query_report.properties = ['{DAV:}getetag']
            address_book_query_report.test = 'anyof'
            address_book_query_report.limit = nil
            address_book_query_report.filters = [
              {
                'name' => 'uid',
                'test' => 'anyof',
                'is-not-defined' => false,
                'param-filters' => [],
                'text-matches' => []
              }
            ]

            assert_instance_equal(
              address_book_query_report,
              result['value']
            )
          end

          def test_deserialize_all_of
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter test="allof">
    <c:prop-filter name="uid" />
  </c:filter>
</c:addressbook-query>
XML

            result = parse(xml)
            address_book_query_report = AddressBookQueryReport.new
            address_book_query_report.properties = ['{DAV:}getetag']
            address_book_query_report.test = 'allof'
            address_book_query_report.limit = nil
            address_book_query_report.filters = [
              {
                'name' => 'uid',
                'test' => 'anyof',
                'is-not-defined' => false,
                'param-filters' => [],
                'text-matches' => []
              }
            ]

            assert_instance_equal(
              address_book_query_report,
              result['value']
            )
          end

          def test_deserialize_bad_test
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
    <d:prop>
      <d:getetag />
    </d:prop>
    <c:filter test="bad">
      <c:prop-filter name="uid" />
    </c:filter>
</c:addressbook-query>
XML

            assert_raises(Dav::Exception::BadRequest) { parse(xml) }
          end

          # We should error on this, but KDE does this, so we chose to support it.
          def test_deserialize_no_filter
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
</c:addressbook-query>
XML

            result = parse(xml)
            address_book_query_report = AddressBookQueryReport.new
            address_book_query_report.properties = ['{DAV:}getetag']
            address_book_query_report.test = 'anyof'
            address_book_query_report.limit = nil
            address_book_query_report.filters = []

            assert_instance_equal(
              address_book_query_report,
              result['value']
            )
          end

          def test_deserialize_complex
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
    <c:address-data content-type="application/vcard+json" version="4.0" />
  </d:prop>
  <c:filter>
    <c:prop-filter name="uid">
      <c:is-not-defined />
    </c:prop-filter>
    <c:prop-filter name="x-foo" test="allof">
      <c:param-filter name="x-param1" />
      <c:param-filter name="x-param2">
        <c:is-not-defined />
      </c:param-filter>
      <c:param-filter name="x-param3">
        <c:text-match match-type="contains">Hello!</c:text-match>
      </c:param-filter>
    </c:prop-filter>
    <c:prop-filter name="x-prop2">
      <c:text-match match-type="starts-with" negate-condition="yes">No</c:text-match>
    </c:prop-filter>
  </c:filter>
  <c:limit><c:nresults>10</c:nresults></c:limit>
</c:addressbook-query>
XML

            result = parse(xml)
            address_book_query_report = AddressBookQueryReport.new
            address_book_query_report.properties = [
              '{DAV:}getetag',
              '{urn:ietf:params:xml:ns:carddav}address-data'
            ]
            address_book_query_report.test = 'anyof'
            address_book_query_report.filters = [
              {
                'name' => 'uid',
                'test' => 'anyof',
                'is-not-defined' => true,
                'param-filters' => [],
                'text-matches' => []
              },
              {
                'name' => 'x-foo',
                'test' => 'allof',
                'is-not-defined' => false,
                'param-filters' => [
                  {
                    'name' => 'x-param1',
                    'is-not-defined' => false,
                    'text-match' => nil
                  },
                  {
                    'name' => 'x-param2',
                    'is-not-defined' => true,
                    'text-match' => nil
                  },
                  {
                    'name' => 'x-param3',
                    'is-not-defined' => false,
                    'text-match' =>  {
                      'negate-condition' => false,
                      'value' => 'Hello!',
                      'match-type' => 'contains',
                      'collation' => 'i;unicode-casemap'
                    }
                  }
                ],
                'text-matches' => []
              },
              {
                'name' => 'x-prop2',
                'test' => 'anyof',
                'is-not-defined' => false,
                'param-filters' => [],
                'text-matches' => [
                  {
                    'negate-condition' => true,
                    'value' => 'No',
                    'match-type' => 'starts-with',
                    'collation' => 'i;unicode-casemap'
                  }
                ]
              }
            ]

            address_book_query_report.version = '4.0'
            address_book_query_report.content_type = 'application/vcard+json'
            address_book_query_report.limit = 10

            assert_instance_equal(
              address_book_query_report,
              result['value']
            )
          end

          def test_deserialize_bad_match_type
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
    <d:prop>
      <d:getetag />
    </d:prop>
    <c:filter>
      <c:prop-filter name="x-foo" test="allof">
        <c:param-filter name="x-param3">
          <c:text-match match-type="bad">Hello!</c:text-match>
        </c:param-filter>
      </c:prop-filter>
    </c:filter>
</c:addressbook-query>
XML

            assert_raises(Dav::Exception::BadRequest) { parse(xml) }
          end

          def test_deserialize_bad_match_type2
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter>
    <c:prop-filter name="x-prop2">
      <c:text-match match-type="bad" negate-condition="yes">No</c:text-match>
    </c:prop-filter>
  </c:filter>
</c:addressbook-query>
XML

            assert_raises(Dav::Exception::BadRequest) { parse(xml) }
          end

          def test_deserialize_double_filter
            xml = <<XML
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
    <d:prop>
      <d:getetag />
    </d:prop>
    <c:filter>
    </c:filter>
    <c:filter>
    </c:filter>
</c:addressbook-query>
XML
            assert_raises(Dav::Exception::BadRequest) { parse(xml) }
          end
        end
      end
    end
  end
end
