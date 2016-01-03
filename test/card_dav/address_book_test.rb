require 'test_helper'

module Tilia
  module CardDav
    class AddressBookTest < Minitest::Test
      def setup
        @backend = Backend::Mock.new
        @address_book = AddressBook.new(
          @backend,

          'uri' => 'book1',
          'id' => 'foo',
          '{DAV:}displayname' => 'd-name',
          'principaluri' => 'principals/user1'
        )
      end

      def test_get_name
        assert_equal('book1', @address_book.name)
      end

      def test_get_child
        card = @address_book.child('card1')
        assert_kind_of(Card, card)
        assert_equal('card1', card.name)
      end

      def test_get_child_not_found
        assert_raises(Dav::Exception::NotFound) do
          @address_book.child('card3')
        end
      end

      def test_get_children
        cards = @address_book.children
        assert_equal(2, cards.size)

        assert_equal('card1', cards[0].name)
        assert_equal('card2', cards[1].name)
      end

      def test_create_directory
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book.create_directory('name')
        end
      end

      def test_create_file
        file = StringIO.new
        file.write('foo')
        file.rewind
        @address_book.create_file('card2', file)

        assert_equal('foo', @backend.instance_variable_get('@cards')['foo']['card2'])
      end

      def test_delete
        @address_book.delete
        assert_equal([], @backend.address_books)
      end

      def test_set_name
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book.name = 'foo'
        end
      end

      def test_get_last_modified
        assert_nil(@address_book.last_modified)
      end

      def test_update_properties
        prop_patch = Dav::PropPatch.new(
          '{DAV:}displayname' => 'barrr'
        )
        @address_book.prop_patch(prop_patch)
        assert(prop_patch.commit)

        assert_equal('barrr', @backend.address_books[0]['{DAV:}displayname'])
      end

      def test_get_properties
        props = @address_book.properties(['{DAV:}displayname'])
        assert_equal(
          {
            '{DAV:}displayname' => 'd-name'
          },
          props
        )
      end

      def test_acl_methods
        assert_equal('principals/user1', @address_book.owner)
        assert_nil(@address_book.group)
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
          @address_book.acl
        )
      end

      def test_set_acl
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book.acl = []
        end
      end

      def test_get_supported_privilege_set
        assert_nil(@address_book.supported_privilege_set)
      end

      def test_get_sync_token_no_sync_support
        assert_nil(@address_book.sync_token)
      end

      def test_get_changes_no_sync_support
        assert_nil(@address_book.changes(1, nil))
      end

      def test_get_sync_token
        ab = AddressBook.new(
          DatabaseUtil.backend,
          'id' => 1,
          '{DAV:}sync-token' => 2
        )
        assert_equal(2, ab.sync_token)
      end

      def test_get_sync_token2
        ab = AddressBook.new(
          DatabaseUtil.backend,
          'id' => 1,
          '{http://sabredav.org/ns}sync-token' => 2
        )
        assert_equal(2, ab.sync_token)
      end

      def test_get_changes
        ab = AddressBook.new(
          DatabaseUtil.backend,
          'id' => 1,
          '{DAV:}sync-token' => 2
        )
        assert_equal(
          {
            'syncToken' => 2,
            'modified' => [],
            'deleted' => [],
            'added' => ['UUID-2345']
          },
          ab.changes(1, 1)
        )
      end
    end
  end
end
