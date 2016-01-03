require 'test_helper'

module Tilia
  module CardDav
    class CardTest < Minitest::Test
      def setup
        @backend = Backend::Mock.new
        @card = Card.new(
          @backend,
          {
            'uri' => 'book1',
            'id' => 'foo',
            'principaluri' => 'principals/user1'
          },
          'uri' => 'card1',
          'addressbookid' => 'foo',
          'carddata' => 'card'
        )
      end

      def test_get
        result = @card.get
        assert_equal('card', result)
      end

      def test_get2
        @card = Card.new(
          @backend,
          {
            'uri' => 'book1',
            'id' => 'foo',
            'principaluri' => 'principals/user1'
          },
          'uri' => 'card1',
          'addressbookid' => 'foo'
        )
        result = @card.get
        assert_equal("BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD", result)
      end

      def test_put
        file = StringIO.new
        file.write('newdata')
        file.rewind
        @card.put(file)
        result = @card.get
        assert_equal('newdata', result)
      end

      def test_delete
        @card.delete
        assert_equal(1, @backend.cards('foo').size)
      end

      def test_get_content_type
        assert_equal('text/vcard; charset=utf-8', @card.content_type)
      end

      def test_get_etag
        assert_equal("\"#{Digest::MD5.hexdigest('card')}\"", @card.etag)
      end

      def test_get_etag2
        card = Card.new(
          @backend,
          {
            'uri' => 'book1',
            'id' => 'foo',
            'principaluri' => 'principals/user1'
          },
          'uri' => 'card1',
          'addressbookid' => 'foo',
          'carddata' => 'card',
          'etag' => '"blabla"'
        )
        assert_equal('"blabla"', card.etag)
      end

      def test_get_last_modified
        assert_nil(@card.last_modified)
      end

      def test_get_size
        assert_equal(4, @card.size)
        assert_equal(4, @card.size)
      end

      def test_get_size2
        card = Card.new(
          @backend,
          {
            'uri' => 'book1',
            'id' => 'foo',
            'principaluri' => 'principals/user1'
          },
          'uri' => 'card1',
          'addressbookid' => 'foo',
          'etag' => '"blabla"',
          'size' => 4
        )
        assert_equal(4, card.size)
      end

      def test_acl_methods
        assert_equal('principals/user1', @card.owner)
        assert_nil(@card.group)
        assert_equal(
          [
            {
              'privilege' => '{DAV:}read',
              'principal' => 'principals/user1',
              'protected' => true
            },
            {
              'privilege' => '{DAV:}write',
              'principal' => 'principals/user1',
              'protected' => true
            }
          ],
          @card.acl
        )
      end

      def test_override_acl
        card = Card.new(
          @backend,
          {
            'uri' => 'book1',
            'id' => 'foo',
            'principaluri' => 'principals/user1'
          },
          'uri' => 'card1',
          'addressbookid' => 'foo',
          'carddata' => 'card',
          'acl' => [
            {
              'privilege' => '{DAV:}read',
              'principal' => 'principals/user1',
              'protected' => true
            }
          ]
        )
        assert_equal(
          [
            {
              'privilege' => '{DAV:}read',
              'principal' => 'principals/user1',
              'protected' => true
            }
          ],
          card.acl
        )
      end

      def test_set_acl
        assert_raises(Dav::Exception::MethodNotAllowed) { @card.acl = [] }
      end

      def test_get_supported_privilege_set
        assert_nil(@card.supported_privilege_set)
      end
    end
  end
end
