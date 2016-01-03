require 'test_helper'

module Tilia
  module CardDav
    class SogoStripContentType < DavServerTest
      def setup
        @setup_card_dav = true
        @carddav_address_books = [
          {
            'id'  => 1,
            'uri' => 'book1',
            'principaluri' => 'principals/user1'
          }
        ]
        @carddav_cards = {
          1 => {
            'card1.vcf' => "BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD"
          }
        }
        super
      end

      def test_dont_strip
        result = @server.properties('addressbooks/user1/book1/card1.vcf', ['{DAV:}getcontenttype'])
        assert_equal(
          {
            '{DAV:}getcontenttype' => 'text/vcard; charset=utf-8'
          },
          result
        )
      end

      def test_strip
        @server.http_request = Http::Sapi.create_from_server_array(
          'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:10.0.2) Gecko/20120216 Thunderbird/10.0.2 Lightning/1.2.1'
        )
        result = @server.properties(
          'addressbooks/user1/book1/card1.vcf',
          ['{DAV:}getcontenttype']
        )
        assert_equal(
          {
            '{DAV:}getcontenttype' => 'text/x-vcard'
          },
          result
        )
      end

      def test_dont_touch_other_mime_types
        @server.http_request = Http::Request.new(
          'GET',
          '/addressbooks/user1/book1/card1.vcf',
          'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:10.0.2) Gecko/20120216 Thunderbird/10.0.2 Lightning/1.2.1'
        )

        prop_find = Dav::PropFind.new('hello', ['{DAV:}getcontenttype'])
        prop_find.set('{DAV:}getcontenttype', 'text/plain')
        @carddav_plugin.prop_find_late(prop_find, Dav::SimpleCollection.new('foo'))
        assert_equal('text/plain', prop_find.get('{DAV:}getcontenttype'))
      end
    end
  end
end
