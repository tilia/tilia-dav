require 'test_helper'

module Tilia
  module CardDav
    class ValidateVCardTest < Minitest::Test
      def setup
        addressbooks = [
          {
            'id' => 'addressbook1',
            'principaluri' => 'principals/admin',
            'uri' => 'addressbook1'
          }
        ]

        @card_backend = Backend::Mock.new(addressbooks, 'addressbook1' => {})
        principal_backend = DavAcl::PrincipalBackend::Mock.new

        tree = [AddressBookRoot.new(principal_backend, @card_backend)]

        @server = Dav::ServerMock.new(tree)
        @server.sapi = Http::SapiMock.new
        @server.debug_exceptions = true

        plugin = Plugin.new
        @server.add_plugin(plugin)

        response = Http::ResponseMock.new
        @server.http_response = response
      end

      def request(request)
        @server.http_request = request
        @server.exec

        @server.http_response
      end

      def test_create_file
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'REQUEST_PATH' => '/addressbooks/admin/addressbook1/blabla.vcf'
        )

        response = request(request)

        assert_equal(415, response.status)
      end

      def test_create_file_valid
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'REQUEST_PATH' => '/addressbooks/admin/addressbook1/blabla.vcf'
        )
        request.body = "BEGIN:VCARD\r\nUID:foo\r\nEND:VCARD\r\n"

        response = request(request)

        assert_equal(201, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
        expected = {
          'uri'          => 'blabla.vcf',
          'carddata' => "BEGIN:VCARD\r\nUID:foo\r\nEND:VCARD\r\n"
        }

        assert_equal(expected, @card_backend.card('addressbook1', 'blabla.vcf'))
      end

      def test_create_file_no_uid
        request = Http::Request.new(
          'PUT',
          '/addressbooks/admin/addressbook1/blabla.vcf'
        )
        request.body = "BEGIN:VCARD\r\nEND:VCARD\r\n"

        response = request(request)

        assert_equal(201, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")

        foo = @card_backend.card('addressbook1', 'blabla.vcf')
        assert(foo['carddata'].index('UID'))
      end

      def test_create_file_json
        request = Http::Request.new(
          'PUT',
          '/addressbooks/admin/addressbook1/blabla.vcf'
        )
        request.body = '[ "vcard" , [ [ "UID" , {}, "text", "foo" ] ] ]'

        response = request(request)

        assert_equal(201, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")

        foo = @card_backend.card('addressbook1', 'blabla.vcf')
        assert_equal("BEGIN:VCARD\r\nUID:foo\r\nEND:VCARD\r\n", foo['carddata'])
      end

      def test_create_file_v_calendar
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'REQUEST_PATH' => '/addressbooks/admin/addressbook1/blabla.vcf'
        )
        request.body = "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"

        response = request(request)

        assert_equal(415, response.status, "Incorrect status returned! Full response body: #{response.body_as_string}")
      end

      def test_update_file
        @card_backend.create_card('addressbook1', 'blabla.vcf', 'foo')
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'REQUEST_PATH' => '/addressbooks/admin/addressbook1/blabla.vcf'
        )

        response = request(request)

        assert_equal(415, response.status)
      end

      def test_update_file_parsable_body
        @card_backend.create_card('addressbook1', 'blabla.vcf', 'foo')
        request = Http::Sapi.create_from_server_array(
          'REQUEST_METHOD' => 'PUT',
          'REQUEST_PATH' => '/addressbooks/admin/addressbook1/blabla.vcf'
        )
        body = "BEGIN:VCARD\r\nUID:foo\r\nEND:VCARD\r\n"
        request.body = body

        response = request(request)

        assert_equal(204, response.status)

        expected = {
          'uri'          => 'blabla.vcf',
          'carddata' => body
        }

        assert_equal(expected, @card_backend.card('addressbook1', 'blabla.vcf'))
      end
    end
  end
end
