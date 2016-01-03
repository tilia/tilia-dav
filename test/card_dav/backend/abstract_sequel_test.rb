module Tilia
  module CardDav
    module Backend
      module AbstractSequelTest
        # @abstract
        # @return PDO
        def sequel
        end

        def setup
          db = sequel
          @backend = Sequel.new(db)
          db.run('INSERT INTO addressbooks (principaluri, displayname, uri, description, synctoken) VALUES ("principals/user1", "book1", "book1", "addressbook 1", 1)')
          db.run('INSERT INTO cards (addressbookid, carddata, uri, lastmodified, etag, size) VALUES (1, "card1", "card1", 0, "' << Digest::MD5.hexdigest('card1') << '", 5)')
        end

        def test_get_address_books_for_user
          result = @backend.address_books_for_user('principals/user1')

          expected = [
            {
              'id' => 1,
              'uri' => 'book1',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'book1',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 1',
              '{http://calendarserver.org/ns/}getctag' => 1,
              '{http://sabredav.org/ns}sync-token' => 1
            }
          ]

          assert_equal(expected, result)
        end

        def test_update_address_book_invalid_prop
          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'updated',
            "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'updated',
            '{DAV:}foo' => 'bar'
          )

          @backend.update_address_book(1, prop_patch)
          result = prop_patch.commit

          refute(result)

          result = @backend.address_books_for_user('principals/user1')

          expected = [
            {
              'id' => 1,
              'uri' => 'book1',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'book1',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 1',
              '{http://calendarserver.org/ns/}getctag' => 1,
              '{http://sabredav.org/ns}sync-token' => 1
            }
          ]

          assert_equal(expected, result)
        end

        def test_update_address_book_no_props
          prop_patch = Dav::PropPatch.new({})

          @backend.update_address_book(1, prop_patch)
          result = prop_patch.commit
          assert(result)

          result = @backend.address_books_for_user('principals/user1')

          expected = [
            {
              'id' => 1,
              'uri' => 'book1',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'book1',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 1',
              '{http://calendarserver.org/ns/}getctag' => 1,
              '{http://sabredav.org/ns}sync-token' => 1
            }
          ]

          assert_equal(expected, result)
        end

        def test_update_address_book_success
          prop_patch = Dav::PropPatch.new(
            '{DAV:}displayname' => 'updated',
            "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'updated'
          )

          @backend.update_address_book(1, prop_patch)
          result = prop_patch.commit

          assert(result)

          result = @backend.address_books_for_user('principals/user1')

          expected = [
            {
              'id' => 1,
              'uri' => 'book1',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'updated',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'updated',
              '{http://calendarserver.org/ns/}getctag' => 2,
              '{http://sabredav.org/ns}sync-token' => 2
            }
          ]

          assert_equal(expected, result)
        end

        def test_delete_address_book
          @backend.delete_address_book(1)

          assert_equal([], @backend.address_books_for_user('principals/user1'))
        end

        def test_create_address_book_unsupported_prop
          assert_raises(Dav::Exception::BadRequest) do
            @backend.create_address_book(
              'principals/user1',
              'book2',
              '{DAV:}foo' => 'bar'
            )
          end
        end

        def test_create_address_book_success
          @backend.create_address_book(
            'principals/user1',
            'book2',
            '{DAV:}displayname' => 'book2',
            "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 2'
          )

          expected = [
            {
              'id' => 1,
              'uri' => 'book1',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'book1',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 1',
              '{http://calendarserver.org/ns/}getctag' => 1,
              '{http://sabredav.org/ns}sync-token' => 1
            },
            {
              'id' => 2,
              'uri' => 'book2',
              'principaluri' => 'principals/user1',
              '{DAV:}displayname' => 'book2',
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => 'addressbook 2',
              '{http://calendarserver.org/ns/}getctag' => 1,
              '{http://sabredav.org/ns}sync-token' => 1
            }
          ]

          result = @backend.address_books_for_user('principals/user1')
          assert_equal(expected, result)
        end

        def test_get_cards
          result = @backend.cards(1)

          expected = [
            {
              'id' => 1,
              'uri' => 'card1',
              'lastmodified' => 0,
              'etag' => "\"#{Digest::MD5.hexdigest('card1')}\"",
              'size' => 5
            }
          ]

          assert_equal(expected, result)
        end

        def test_get_card
          result = @backend.card(1, 'card1')

          expected = {
            'id' => 1,
            'uri' => 'card1',
            'carddata' => 'card1',
            'lastmodified' => 0,
            'etag' => "\"#{Digest::MD5.hexdigest('card1')}\"",
            'size' => 5
          }

          assert_equal(expected, result)
        end

        def test_create_card
          result = @backend.create_card(1, 'card2', 'data2')
          assert_equal("\"#{Digest::MD5.hexdigest('data2')}\"", result)
          result = @backend.card(1, 'card2')
          assert_equal(2, result['id'])
          assert_equal('card2', result['uri'])
          assert_equal('data2', result['carddata'])
        end

        def test_get_multiple
          result = @backend.create_card(1, 'card2', 'data2')
          result = @backend.create_card(1, 'card3', 'data3')
          check = [
            {
              'id' => 1,
              'uri' => 'card1',
              'carddata' => 'card1',
              'lastmodified' => 0
            },
            {
              'id' => 2,
              'uri' => 'card2',
              'carddata' => 'data2',
              'lastmodified' => Time.now.to_i
            },
            {
              'id' => 3,
              'uri' => 'card3',
              'carddata' => 'data3',
              'lastmodified' => Time.now.to_i
            }
          ]

          result = @backend.multiple_cards(1, ['card1', 'card2', 'card3'])

          check.each do |node|
            node.each do |k, v|
              if k != 'lastmodified'
                assert_equal(v, node[k])
              else
                # 60 seconds delta should be fine ...
                assert_in_delta(v, node[k], 60)
              end
            end
          end
        end

        def test_update_card
          result = @backend.update_card(1, 'card1', 'newdata')
          assert_equal("\"#{Digest::MD5.hexdigest('newdata')}\"", result)

          result = @backend.card(1, 'card1')
          assert_equal(1, result['id'])
          assert_equal('newdata', result['carddata'])
        end

        def test_delete_card
          @backend.delete_card(1, 'card1')
          result = @backend.card(1, 'card1')
          refute(result)
        end

        def test_get_changes
          backend = @backend
          id = backend.create_address_book(
            'principals/user1',
            'bla',
            []
          )
          result = backend.changes_for_address_book(id, nil, 1)

          assert_equal(
            {
              'syncToken' => 1,
              'added'     => [],
              'modified'  => [],
              'deleted'   => []
            },
            result
          )

          current_token = result['syncToken']

          dummy_card = "BEGIN:VCARD\r\nEND:VCARD\r\n"

          backend.create_card(id, 'card1.ics', dummy_card)
          backend.create_card(id, 'card2.ics', dummy_card)
          backend.create_card(id, 'card3.ics', dummy_card)
          backend.update_card(id, 'card1.ics', dummy_card)
          backend.delete_card(id, 'card2.ics')

          result = backend.changes_for_address_book(id, current_token, 1)

          assert_equal(
            {
              'syncToken' => 6,
              'modified'  => ['card1.ics'],
              'deleted'   => ['card2.ics'],
              'added'     => ['card3.ics']
            },
            result
          )
        end
      end
    end
  end
end
