module Tilia
  module CardDav
    module Backend
      # CardDAV Backend Interface
      #
      # Any CardDAV backend must implement this interface.
      #
      # Note that there are references to 'addressBookId' scattered throughout the
      # class. The value of the addressBookId is completely up to you, it can be any
      # arbitrary value you can use as an unique identifier.
      #
      # @copyright Copyright (C) 2007-2015 fruux GmbH (https://fruux.com/).
      # @author Evert Pot (http://evertpot.com/)
      # @license http://sabre.io/license/ Modified BSD License
      module BackendInterface
        # Returns the list of addressbooks for a specific user.
        #
        # Every addressbook should have the following properties:
        #   id - an arbitrary unique id
        #   uri - the 'basename' part of the url
        #   principaluri - Same as the passed parameter
        #
        # Any additional clark-notation property may be passed besides this. Some
        # common ones are :
        #   {DAV:}displayname
        #   {urn:ietf:params:xml:ns:carddav}addressbook-description
        #   {http://calendarserver.org/ns/}getctag
        #
        # @param string principal_uri
        # @return array
        def address_books_for_user(principal_uri)
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
        end

        # Creates a new address book
        #
        # @param string principal_uri
        # @param string url Just the 'basename' of the url.
        # @param array properties
        # @return void
        def create_address_book(principal_uri, url, properties)
        end

        # Deletes an entire addressbook and all its contents
        #
        # @param mixed address_book_id
        # @return void
        def delete_address_book(address_book_id)
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
        end

        # Deletes a card
        #
        # @param mixed address_book_id
        # @param string card_uri
        # @return bool
        def delete_card(address_book_id, card_uri)
        end
      end
    end
  end
end
