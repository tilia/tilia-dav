module Tilia
  module CardDav
    module Backend
      class Mock < AbstractBackend
        attr_accessor :address_books
        attr_accessor :cards

        def initialize(address_books = nil, cards = nil)
          @address_books = address_books
          @cards = cards

          unless @address_books
            @address_books = [
              {
                'id' => 'foo',
                'uri' => 'book1',
                'principaluri' => 'principals/user1',
                '{DAV:}displayname' => 'd-name'
              }
            ]

            card2 = StringIO.new
            card2.write("BEGIN:VCARD\nVERSION:3.0\nUID:45678\nEND:VCARD")
            card2.rewind
            @cards = {
              'foo' => {
                'card1' => "BEGIN:VCARD\nVERSION:3.0\nUID:12345\nEND:VCARD",
                'card2' => card2
              }
            }
          end
        end

        def address_books_for_user(principal_uri)
          books = []
          @address_books.each do |book|
            books << book if book['principaluri'] == principal_uri
          end

          books
        end

        # Updates properties for an address book.
        #
        # The list of mutations is stored in a Sabre\DAV\PropPatch object.
        # To do the actual updates, you must tell this object which properties
        # you're going to process with the handle method.
        #
        # Calling the handle method is like telling the PropPatch object "I
        # promise I can handle updating this property".
        #
        # Read the PropPatch documenation for more info and examples.
        #
        # @param string address_book_id
        # @param \Sabre\DAV\PropPatch prop_patch
        # @return void
        def update_address_book(address_book_id, prop_patch)
          @address_books.each do |book|
            next unless book['id'] == address_book_id

            prop_patch.handle_remaining(
              lambda do |mutations|
                mutations.each do |key, value|
                  book[key] = value
                end
                return true
              end
            )
          end
        end

        def create_address_book(principal_uri, url, properties)
          @address_books << properties.merge(
            'id' => url,
            'uri' => url,
            'principaluri' => principal_uri
          )
        end

        def delete_address_book(address_book_id)
          @address_books.delete_if do |value|
            value['id'] == address_book_id
          end
          @cards.delete(address_book_id)
        end

        def cards(address_book_id)
          cards = []
          @cards[address_book_id].each do |uri, data|
            cards << {
              'uri' => uri,
              'carddata' => data
            }
          end

          cards
        end

        def card(address_book_id, card_uri)
          return false unless @cards[address_book_id].key?(card_uri)

          {
            'uri' => card_uri,
            'carddata' => @cards[address_book_id][card_uri]
          }
        end

        def create_card(address_book_id, card_uri, card_data)
          @cards[address_book_id][card_uri] = card_data
        end

        def update_card(address_book_id, card_uri, card_data)
          @cards[address_book_id][card_uri] = card_data
        end

        def delete_card(address_book_id, card_uri)
          @cards[address_book_id].delete(card_uri)
        end
      end
    end
  end
end
