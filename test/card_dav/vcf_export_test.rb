require 'test_helper'

module Tilia
  module CardDav
    class VcfExportTest < DavServerTest
      def setup
        @setup_card_dav = true
        @auto_login = 'user1'
        @setup_acl = true

        @carddav_address_books = [
          {
            'id' => 'book1',
            'uri' => 'book1',
            'principaluri' => 'principals/user1'
          }
        ]
        @carddav_cards = {
          'book1' => {
            'card1' => "BEGIN:VCARD\r\nFN:Person1\r\nEND:VCARD\r\n",
            'card2' => "BEGIN:VCARD\r\nFN:Person2\r\nEND:VCARD",
            'card3' => "BEGIN:VCARD\r\nFN:Person3\r\nEND:VCARD\r\n",
            'card4' => "BEGIN:VCARD\nFN:Person4\nEND:VCARD\n"
          }
        }
        super
        @server.add_plugin(VcfExportPlugin.new)
      end

      def test_simple
        plugin = @server.plugin('vcf-export')
        assert_kind_of(VcfExportPlugin, plugin)
        assert_equal('vcf-export', plugin.plugin_info['name'])
      end

      def test_export
        request = Http::Sapi.create_from_server_array(
          'PATH_INFO'      => '/addressbooks/user1/book1',
          'QUERY_STRING'   => 'export',
          'REQUEST_METHOD' => 'GET'
        )

        response = request(request)
        assert_equal(200, response.status, response.body)

        expected = <<VCF
BEGIN:VCARD
FN:Person1
END:VCARD
BEGIN:VCARD
FN:Person2
END:VCARD
BEGIN:VCARD
FN:Person3
END:VCARD
BEGIN:VCARD
FN:Person4
END:VCARD
VCF

        # We actually expected windows line endings
        expected = expected.gsub("\n", "\r\n")

        assert_equal(expected, response.body_as_string)
      end

      def test_browser_integration
        plugin = @server.plugin('vcf-export')
        actions = Box.new('')
        addressbook = AddressBook.new(@carddav_backend, [])
        @server.emit('browserButtonActions', ['/foo', addressbook, actions])
        assert(actions.value.index('/foo?export'))
      end
    end
  end
end
