module Tilia
  module CardDav
    module Backend
      # CardDAV abstract Backend
      #
      # This class serves as a base-class for addressbook backends
      #
      # This class doesn't do much, but it was added for consistency.
      class AbstractBackend
        include BackendInterface

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
          uris.map do |uri|
            card(address_book_id, uri)
          end
        end
      end
    end
  end
end
