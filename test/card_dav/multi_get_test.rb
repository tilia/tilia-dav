require 'test_helper'

module Tilia
  module CardDav
    class MultiGetTest < AbstractPluginTest
      def test_multi_get
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'PATH_INFO'      => '/addressbooks/user1/book1'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-multiget xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
    <c:address-data />
  </d:prop>
  <d:href>/addressbooks/user1/book1/card1</d:href>
</c:addressbook-multiget>
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
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\"",
                '{urn:ietf:params:xml:ns:carddav}address-data' => "BEGIN:VCARD\r\nVERSION:3.0\r\nUID:12345\r\nEND:VCARD\r\n"
              }
            }
          },
          result
        )
      end

      def test_multi_get_v_card4
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'REPORT',
          'PATH_INFO'      => '/addressbooks/user1/book1'
        )

        request.body = <<BODY
<?xml version="1.0"?>
<c:addressbook-multiget xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag />
    <c:address-data content-type="text/vcard" version="4.0" />
  </d:prop>
  <d:href>/addressbooks/user1/book1/card1</d:href>
</c:addressbook-multiget>
BODY

        response = Http::ResponseMock.new

        @server.http_request = request
        @server.http_response = response

        @server.exec

        assert_equal(207, response.status, "Incorrect status code. Full response body: #{response.body_as_string}")

        # using the client for parsing
        client = Dav::Client.new('baseUri' => '/')

        result = client.parse_multi_status(response.body)

        prod_id = "PRODID:-//Tilia//Tilia VObject #{VObject::Version::VERSION}//EN"

        assert_equal(
          {
            '/addressbooks/user1/book1/card1' => {
              '200' => {
                '{DAV:}getetag' => "\"#{Digest::MD5.hexdigest("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD")}\"",
                '{urn:ietf:params:xml:ns:carddav}address-data' => "BEGIN:VCARD\r\nVERSION:4.0\r\n#{prod_id}\r\nUID:12345\r\nEND:VCARD\r\n"
              }
            }
          },
          result
        )
      end
    end
  end
end
