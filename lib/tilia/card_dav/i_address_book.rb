module Tilia
  module CardDav
    # AddressBook interface
    #
    # Implement this interface to allow a node to be recognized as an addressbook.
    module IAddressBook
      include Dav::ICollection
    end
  end
end
