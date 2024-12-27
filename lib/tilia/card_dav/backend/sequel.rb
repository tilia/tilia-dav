module Tilia
  module CardDav
    module Backend
      # Sequel CardDAV backend
      #
      # This CardDAV backend uses Sequel to store addressbooks
      class Sequel < AbstractBackend
        include SyncSupport

        # @!attribute [rw] sequel
        #   @!visibility private
        #   Sequel connection
        #
        #     @return [Sequel]

        # The Sequel table name used to store addressbooks
        attr_accessor :address_books_table_name

        # The Sequel table name used to store cards
        attr_accessor :cards_table_name

        # The table name that will be used for tracking changes in address books.
        #
        # @var string
        attr_accessor :address_book_changes_table_name

        # Sets up the object
        #
        # @param \Sequel sequel
        def initialize(sequel)
          @address_books_table_name = 'addressbooks'
          @cards_table_name = 'cards'
          @address_book_changes_table_name = 'addressbookchanges'
          @sequel = sequel
        end

        # Returns the list of addressbooks for a specific user.
        #
        # @param string principal_uri
        # @return array
        def address_books_for_user(principal_uri)
          address_books = []
          @sequel.fetch("SELECT id, uri, displayname, principaluri, description, synctoken FROM #{@address_books_table_name} WHERE principaluri = ?", principal_uri) do |row|
            address_books << {
              'id'                                             => row[:id],
              'uri'                                            => row[:uri],
              'principaluri'                                   => row[:principaluri],
              '{DAV:}displayname'                              => row[:displayname],
              "{#{Plugin::NS_CARDDAV}}addressbook-description" => row[:description],
              '{http://calendarserver.org/ns/}getctag'         => row[:synctoken],
              '{http://sabredav.org/ns}sync-token'             => row[:synctoken] ? row[:synctoken] : '0'
            }
          end

          address_books
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
          supported_properties = [
            '{DAV:}displayname',
            "{#{Plugin::NS_CARDDAV}}addressbook-description"
          ]

          prop_patch.handle(
            supported_properties,
            lambda do |mutations|
              updates = {}
              mutations.each do |property, new_value|
                case property
                when '{DAV:}displayname'
                  updates[:displayname] = new_value
                when "{#{Plugin::NS_CARDDAV}}addressbook-description"
                  updates[:description] = new_value
                end
              end

              query = "UPDATE #{@address_books_table_name} SET "
              first = true
              updates.each do |key, _value|
                if first
                  first = false
                else
                  query << ', '
                end
                query << " `#{key}` = :#{key}"
              end

              query << ' WHERE id = :addressbookid'
              updates[:addressbookid] = address_book_id

              ds = @sequel[
                query,
                updates
              ]
              ds.update

              add_change(address_book_id, '', 2)

              return true
            end
          )
        end

        # Creates a new address book
        #
        # @param string principal_uri
        # @param string url Just the 'basename' of the url.
        # @param array properties
        # @return [Integer] last insert id
        def create_address_book(principal_uri, url, properties)
          values = {
            displayname: nil,
            description: nil,
            principaluri: principal_uri,
            uri: url
          }

          properties.each do |property, new_value|
            case property
            when '{DAV:}displayname'
              values[:displayname] = new_value
            when "{#{Plugin::NS_CARDDAV}}addressbook-description"
              values[:description] = new_value
            else
              fail Dav::Exception::BadRequest, "Unknown property: #{property}"
            end
          end

          ds = @sequel[
            "INSERT INTO #{@address_books_table_name} (uri, displayname, description, principaluri, synctoken) VALUES (:uri, :displayname, :description, :principaluri, 1)",
            values
          ]
          ds.insert
        end

        # Deletes an entire addressbook and all its contents
        #
        # @param int address_book_id
        # @return void
        def delete_address_book(address_book_id)
          ds = @sequel["DELETE FROM #{@cards_table_name} WHERE addressbookid = ?", address_book_id]
          ds.delete

          ds = @sequel["DELETE FROM #{@address_books_table_name} WHERE id = ?", address_book_id]
          ds.delete

          ds = @sequel["DELETE FROM #{@address_book_changes_table_name} WHERE id = ?", address_book_id]
          ds.delete
        end

        # Returns all cards for a specific addressbook id.
        #
        # This method should return the following properties for each card:
        #   * carddata - raw vcard data
        #   * uri - Some unique url
        #   * lastmodified - A unix timestamp
        #
        # It's recommended to also return the following properties:
        #   * etag - A unique etag. This must change every time the card changes.
        #   * size - The size of the card in bytes.
        #
        # If these last two properties are provided, less time will be spent
        # calculating them. If they are specified, you can also ommit carddata.
        # This may speed up certain requests, especially with large cards.
        #
        # @param mixed addressbook_id
        # @return array
        def cards(addressbook_id)
          result = []
          @sequel.fetch("SELECT id, uri, lastmodified, etag, size FROM #{@cards_table_name} WHERE addressbookid = ?", addressbook_id) do |row|
            row[:etag] = "\"#{row[:etag]}\""
            result << row.stringify_keys
          end

          result
        end

        # Returns a specfic card.
        #
        # The same set of properties must be returned as with getCards. The only
        # exception is that 'carddata' is absolutely required.
        #
        # If the card does not exist, you must return false.
        #
        # @param mixed address_book_id
        # @param string card_uri
        # @return array
        def card(address_book_id, card_uri)
          ds = @sequel["SELECT id, carddata, uri, lastmodified, etag, size FROM #{@cards_table_name} WHERE addressbookid = ? AND uri = ? LIMIT 1", address_book_id, card_uri]

          result = ds.all.first

          return nil unless result

          result[:etag] = "\"#{result[:etag]}\""
          result.stringify_keys
        end

        # Returns a list of cards.
        #
        # This method should work identical to getCard, but instead return all the
        # cards in the list as an array.
        #
        # If the backend supports this, it may allow for some speed-ups.
        #
        # @param mixed address_book_id
        # @param array uris
        # @return array
        def multiple_cards(address_book_id, uris)
          query = "SELECT id, uri, lastmodified, etag, size, carddata FROM #{@cards_table_name} WHERE addressbookid = ? AND uri IN ("
          # Inserting a whole bunch of question marks
          query << (['?'] * uris.size).join(',')
          query << ')'

          result = []
          @sequel.fetch(query, address_book_id, *uris) do |row|
            row[:etag] = "\"#{row[:etag]}\""
            result << row.stringify_keys
          end

          result
        end

        # Creates a new card.
        #
        # The addressbook id will be passed as the first argument. This is the
        # same id as it is returned from the getAddressBooksForUser method.
        #
        # The cardUri is a base uri, and doesn't include the full path. The
        # cardData argument is the vcard body, and is passed as a string.
        #
        # It is possible to return an ETag from this method. This ETag is for the
        # newly created resource, and must be enclosed with double quotes (that
        # is, the string itself must contain the double quotes).
        #
        # You should only return the ETag if you store the carddata as-is. If a
        # subsequent GET request on the same card does not have the same body,
        # byte-by-byte and you did return an ETag here, clients tend to get
        # confused.
        #
        # If you don't return an ETag, you can just return null.
        #
        # @param mixed address_book_id
        # @param string card_uri
        # @param string card_data
        # @return string|null
        def create_card(address_book_id, card_uri, card_data)
          etag = Digest::MD5.hexdigest(card_data)

          ds = @sequel[
            "INSERT INTO #{@cards_table_name} (carddata, uri, lastmodified, addressbookid, size, etag) VALUES (?, ?, ?, ?, ?, ?)",
            card_data,
            card_uri,
            Time.now.to_i,
            address_book_id,
            card_data.size,
            etag,
          ]
          ds.insert

          add_change(address_book_id, card_uri, 1)

          "\"#{etag}\""
        end

        # Updates a card.
        #
        # The addressbook id will be passed as the first argument. This is the
        # same id as it is returned from the getAddressBooksForUser method.
        #
        # The cardUri is a base uri, and doesn't include the full path. The
        # cardData argument is the vcard body, and is passed as a string.
        #
        # It is possible to return an ETag from this method. This ETag should
        # match that of the updated resource, and must be enclosed with double
        # quotes (that is: the string itself must contain the actual quotes).
        #
        # You should only return the ETag if you store the carddata as-is. If a
        # subsequent GET request on the same card does not have the same body,
        # byte-by-byte and you did return an ETag here, clients tend to get
        # confused.
        #
        # If you don't return an ETag, you can just return null.
        #
        # @param mixed address_book_id
        # @param string card_uri
        # @param string card_data
        # @return string|null
        def update_card(address_book_id, card_uri, card_data)
          etag = Digest::MD5.hexdigest(card_data)

          ds = @sequel[
            "UPDATE #{@cards_table_name} SET carddata = ?, lastmodified = ?, size = ?, etag = ? WHERE uri = ? AND addressbookid =?",
            card_data,
            Time.now.to_i,
            card_data.size,
            etag,
            card_uri,
            address_book_id,
          ]
          ds.insert

          add_change(address_book_id, card_uri, 2)

          "\"#{etag}\""
        end

        # Deletes a card
        #
        # @param mixed address_book_id
        # @param string card_uri
        # @return bool
        def delete_card(address_book_id, card_uri)
          ds = @sequel["DELETE FROM #{@cards_table_name} WHERE addressbookid = ? AND uri = ?", address_book_id, card_uri]
          result = ds.delete

          add_change(address_book_id, card_uri, 3)

          result == 1
        end

        # The getChanges method returns all the changes that have happened, since
        # the specified syncToken in the specified address book.
        #
        # This function should return an array, such as the following:
        #
        # [
        #   'syncToken' => 'The current synctoken',
        #   'added'   => [
        #      'new.txt',
        #   ],
        #   'modified'   => [
        #      'updated.txt',
        #   ],
        #   'deleted' => [
        #      'foo.php.bak',
        #      'old.txt'
        #   ]
        # ]
        #
        # The returned syncToken property should reflect the *current* syncToken
        # of the addressbook, as reported in the {http://sabredav.org/ns}sync-token
        # property. This is needed here too, to ensure the operation is atomic.
        #
        # If the sync_token argument is specified as null, this is an initial
        # sync, and all members should be reported.
        #
        # The modified property is an array of nodenames that have changed since
        # the last token.
        #
        # The deleted property is an array with nodenames, that have been deleted
        # from collection.
        #
        # The sync_level argument is basically the 'depth' of the report. If it's
        # 1, you only have to report changes that happened only directly in
        # immediate descendants. If it's 2, it should also include changes from
        # the nodes below the child collections. (grandchildren)
        #
        # The limit argument allows a client to specify how many results should
        # be returned at most. If the limit is not specified, it should be treated
        # as infinite.
        #
        # If the limit (infinite or not) is higher than you're willing to return,
        # you should throw a Sabre\DAV\Exception\Too_much_matches exception.
        #
        # If the syncToken is expired (due to data cleanup) or unknown, you must
        # return null.
        #
        # The limit is 'suggestive'. You are free to ignore it.
        #
        # @param string address_book_id
        # @param string sync_token
        # @param int sync_level
        # @param int limit
        # @return array
        def changes_for_address_book(address_book_id, sync_token, _sync_level, limit = nil)
          # Current synctoken
          ds = @sequel["SELECT synctoken FROM #{@address_books_table_name} WHERE id = ?", address_book_id]
          result = ds.all.first

          return nil unless result

          current_token = result[:synctoken]

          return nil unless current_token

          result = {
            'syncToken' => current_token,
            'added'     => [],
            'modified'  => [],
            'deleted'   => []
          }

          if sync_token
            query = "SELECT uri, operation FROM #{@address_book_changes_table_name} WHERE synctoken >= ? AND synctoken < ? AND addressbookid = ? ORDER BY synctoken"
            query << " LIMIT #{limit}" if limit && limit > 0

            # Fetching all changes

            changes = {}

            # This loop ensures that any duplicates are overwritten, only the
            # last change on a node is relevant.
            @sequel.fetch(query, sync_token, current_token, address_book_id) do |row|
              changes[row[:uri]] = row[:operation]
            end

            changes.each do |uri, operation|
              case operation
              when 1
                result['added'] << uri.to_s
              when 2
                result['modified'] << uri.to_s
              when 3
                result['deleted'] << uri.to_s
              end
            end
          else
            # No synctoken supplied, this is the initial sync.
            ds = @sequel["SELECT uri FROM #{@cards_table_name} WHERE addressbookid = ?", address_book_id]

            # RUBY: concert symbols to strings
            result['added'] = ds.all.map { |e| e[:uri] }
          end

          result
        end

        protected

        # Adds a change record to the addressbookchanges table.
        #
        # @param mixed address_book_id
        # @param string object_uri
        # @param int operation 1 = add, 2 = modify, 3 = delete
        # @return void
        def add_change(address_book_id, object_uri, operation)
          ds = @sequel[
            "INSERT INTO #{@address_book_changes_table_name} (uri, synctoken, addressbookid, operation) SELECT ?, synctoken, ?, ? FROM #{@address_books_table_name} WHERE id = ?",
            object_uri,
            address_book_id,
            operation,
            address_book_id
          ]
          ds.insert
          ds = @sequel[
            "UPDATE #{@address_books_table_name} SET synctoken = synctoken + 1 WHERE id = ?",
            address_book_id
          ]
          ds.update
        end

        # TODO: document
        def stringify_keys(hash)
          stringified = {}
          hash.each { |k, v| stringified[k.to_s] = v }
          stringified
        end
      end
    end
  end
end
