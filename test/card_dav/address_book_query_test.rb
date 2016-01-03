require 'test_helper'

module Tilia
  module CardDav
    class AddressBookQueryTest < AbstractPluginTest
      def test_query
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'REQUEST_PATH'   => '/addressbooks/user1/book1',
          'HTTP_DEPTH'     => '1'
        )

        request.body = <<XML
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

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\""
              }
            },
            '/addressbooks/user1/book1/card2' => {
              '404' => {
                '{DAV:}getetag' => nil
              }
            }
          },
          result
        )
      end

      def test_query_depth0
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'REQUEST_PATH' => '/addressbooks/user1/book1/card1',
          'HTTP_DEPTH' => '0'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter>
    <c:prop-filter name="uid" />
  </c:filter>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\""
              }
            }
          },
          result
        )
      end

      def test_query_no_match
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'REQUEST_PATH' => '/addressbooks/user1/book1',
          'HTTP_DEPTH' => '1'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter>
    <c:prop-filter name="email" />
  </c:filter>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        assert_equal({}, result)
      end

      def test_query_limit
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'REQUEST_PATH' => '/addressbooks/user1/book1',
          'HTTP_DEPTH' => '1'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
  </d:prop>
  <c:filter>
    <c:prop-filter name="uid" />
  </c:filter>
  <c:limit><c:nresults>1</c:nresults></c:limit>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\""
              }
            }
          },
          result
        )
      end

      def test_json
        request = Http::Request.new(
          'REPORT',
          '/addressbooks/user1/book1/card1',
          'Depth' => '0'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <c:address-data content-type="application/vcard+json" />
    <d:getetag />
  </d:prop>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        vobj_version = VObject::Version::VERSION

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\"",
                '{urn:ietf:params:xml:ns:carddav}address-data' => '["vcard",[["version",{},"text","4.0"],["prodid",{},"text","-//Tilia//Tilia VObject ' << vobj_version << '//EN"],["uid",{},"text","12345"]]]'
              }
            }
          },
          result
        )
      end

      def test_v_card4
        request = Http::Request.new(
          'REPORT',
          '/addressbooks/user1/book1/card1',
          'Depth' => '0'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <c:address-data content-type="text/vcard" version="4.0" />
    <d:getetag />
  </d:prop>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        vobj_version = VObject::Version::VERSION

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\"",
                '{urn:ietf:params:xml:ns:carddav}address-data' => "BEGIN:VCARD\r\nVERSION:4.0\r\nPRODID:-//Tilia//Tilia VObject #{vobj_version}//EN\r\nUID:12345\r\nEND:VCARD\r\n"
              }
            }
          },
          result
        )
      end

      def test_address_book_depth0
        request = Http::Request.new(
          'REPORT',
          '/addressbooks/user1/book1',
          'Depth' => '0'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <c:address-data content-type="application/vcard+json" />
    <d:getetag />
  </d:prop>
</c:addressbook-query>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(415, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")
      end
    end
  end
end
