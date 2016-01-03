require 'test_helper'

module Tilia
  module CardDav
    class AddressBookHomeTest < Minitest::Test
      def setup
        @backend = Backend::Mock.new
        @address_book_home = AddressBookHome.new(
          @backend,
          'principals/user1'
        )
      end

      def test_get_name
        assert_equal('user1', @address_book_home.name)
      end

      def test_set_name
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book_home.name = 'user2'
        end
      end

      def test_delete
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book_home.delete
        end
      end

      def test_get_last_modified
        assert_nil(@address_book_home.last_modified)
      end

      def test_create_file
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book_home.create_file('bla')
        end
      end

      def test_create_directory
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book_home.create_directory('bla')
        end
      end

      def test_get_child
        child = @address_book_home.child('book1')
        assert_kind_of(AddressBook, child)
        assert_equal('book1', child.name)
      end

      def test_get_child404
        assert_raises(Dav::Exception::NotFound) do
          @address_book_home.child('book2')
        end
      end

      def test_get_children
        children = @address_book_home.children
        assert_equal(1, children.size)
        assert_kind_of(AddressBook, children[0])
        assert_equal('book1', children[0].name)
      end

      def test_create_extended_collection
        resource_type = [
          "{#{Plugin::NS_CARDDAV}}addressbook",
          '{DAV:}collection'
        ]
        @address_book_home.create_extended_collection('book2', Dav::MkCol.new(resource_type, '{DAV:}displayname' => 'a-book 2'))

        assert_equal(
          {
            'id' => 'book2',
            'uri' => 'book2',
            '{DAV:}displayname' => 'a-book 2',
            'principaluri' => 'principals/user1'
          },
          @backend.address_books[1]
        )
      end

      def test_create_extended_collection_invalid
        resource_type = ['{DAV:}collection']

        assert_raises(Dav::Exception::InvalidResourceType) do
          @address_book_home.create_extended_collection(
            'book2',
            Dav::MkCol.new(
              resource_type,
              '{DAV:}displayname' => 'a-book 2'
            )
          )
        end
      end

      def test_acl_methods
        assert_equal('principals/user1', @address_book_home.owner)
        assert_nil(@address_book_home.group)
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
          @address_book_home.acl
        )
      end

      def test_set_acl
        assert_raises(Dav::Exception::MethodNotAllowed) do
          @address_book_home.acl = []
        end
      end

      def test_get_supported_privilege_set
        assert_nil(@address_book_home.supported_privilege_set)
      end
    end
  end
end
